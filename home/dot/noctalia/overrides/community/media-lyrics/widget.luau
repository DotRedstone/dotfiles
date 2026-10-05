--!nonstrict
-- Bar widget: now-playing chip with real-time subtitles and audio visualizer wave.
-- Settings are [[widget.setting]] entries read via noctalia.getConfig(key).

local lyrics_lib = require("./lyrics_lib.luau")

local glyphPlay = "player-play"
local glyphPause = "player-pause"

local GAP = 6
local FONT_PX = 12
local CHAR_PX = FONT_PX * 0.62     -- ~7.4 px per char
local SCROLL_TICKS = 4             -- advance one char every N update ticks (with 50ms interval)

local GLYPHS = { " ", "⡀", "⣀", "⣄", "⣤", "⣦", "⣶", "⣷", "⣿" }

local function readAudioWaves()
  local ok, content = pcall(function() return noctalia.readFile("/dev/shm/cava_bars") end)
  if not ok or not content or content == "" then return "" end
  local out = {}
  for num in content:gmatch("(%d+);") do
    local v = tonumber(num) or 0
    local idx = math.min(#GLYPHS, math.max(1, v + 1))
    out[#out + 1] = GLYPHS[idx]
    if #out >= 5 then break end
  end
  if #out == 0 then return "" end
  return table.concat(out)
end

-- Which panel preset to open (panel_size plugin setting).
local function panelIdForSize()
  local sz = noctalia.getConfig("panel_size")
  if sz == "mini" then return "panel-mini" end
  if sz == "compact" then return "panel-compact" end
  if sz == "large" then return "panel-large" end
  return "panel"
end

-- ── settings ────────────────────────────────────────────────────────────────

local function cfgBool(key, fallback)
  local v = noctalia.getConfig(key)
  if type(v) == "boolean" then return v end
  return fallback
end

local function cfgInt(key, fallback)
  local v = noctalia.getConfig(key)
  if type(v) == "number" then return math.floor(v) end
  return fallback
end

local function widgetOptions()
  local artOnly = cfgBool("album_art_only", false)
  local hideArt = cfgBool("hide_album_art", false)
  local scroll = noctalia.getConfig("title_scroll") or "always"
  if scroll ~= "always" and scroll ~= "on_hover" and scroll ~= "none" then scroll = "always" end
  return {
    artOnly = artOnly,
    hideArt = hideArt,
    hideArtist = cfgBool("hide_artist", false),
    artistFirst = cfgBool("artist_first", false),
    showLine = cfgBool("show_lyric_line", true),
    maxLength = cfgInt("max_length", 360),
    artSize = math.max(8, math.min(96, cfgInt("art_size", 16))),
    scroll = scroll,
    hideWhenNoMedia = cfgBool("hide_when_no_media", false),
  }
end

-- ── utf-8 helpers ───────────────────────────────────────────────────────────

local function charCount(s)
  local i, n = 1, 0
  while i <= #s do
    local b = s:byte(i)
    if b >= 0xF0 then i = i + 4
    elseif b >= 0xE0 then i = i + 3
    elseif b >= 0xC0 then i = i + 2
    else i = i + 1 end
    n = n + 1
  end
  return n
end

local function toChars(s)
  local out = {}
  local i = 1
  while i <= #s do
    local b = s:byte(i)
    local len = 1
    if b >= 0xF0 then len = 4
    elseif b >= 0xE0 then len = 3
    elseif b >= 0xC0 then len = 2 end
    out[#out + 1] = s:sub(i, i + len - 1)
    i = i + len
  end
  return out
end

local function charPrefix(s, maxChars)
  local i, n = 1, 0
  while i <= #s and n < maxChars do
    local b = s:byte(i)
    if b >= 0xF0 then i = i + 4
    elseif b >= 0xE0 then i = i + 3
    elseif b >= 0xC0 then i = i + 2
    else i = i + 1 end
    n = n + 1
  end
  return s:sub(1, i - 1)
end

-- ── text (build + scroll) ───────────────────────────────────────────────────

local scrollOffset = 0
local scrollTick = 0
local hovered = false
local lastFull = ""
local currentWave = ""

local function activeLyricLine(m)
  if m == nil then return nil end
  if m.lyricsStatus ~= "ready" and m.lyricsStatus ~= "choose" then return nil end
  if not m.synced then return nil end
  local lines = m.lyrics
  if type(lines) ~= "table" or #lines == 0 then return nil end
  local pos = tonumber(m.posSec) or 0
  local idx = nil
  for i, l in ipairs(lines) do
    local t = tonumber(l.time) or -1
    if t >= 0 and t <= pos then idx = i end
  end
  if idx == nil then idx = 1 end
  local text = lines[idx] and lines[idx].text or ""
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  return text
end

local function buildFull(m, o)
  local rawTitle = m.title or ""
  local rawArtist = m.artist or ""

  -- [Realtime Subtitle / Lyric Mode]
  if rawTitle:find("^♪") or rawTitle:find("^♩") then
    -- Reject known subtitle UI artifacts; fall through to normal title display
    if not (rawTitle:find("添加字幕") or rawTitle:find("点击添加") or rawTitle:find("字幕设置")) then
      local cleaned = rawTitle:gsub("^[♪♩♫♬%s]+", ""):gsub("[♪♩♫♬%s]+$", "")
      return (cleaned ~= "") and ("♪ " .. cleaned) or rawTitle
    end
  end

  local line = o.showLine and activeLyricLine(m) or nil
  if line then
    -- Pure lyric text only when available, never prepend song title
    return line
  end

  local cleanTitle = lyrics_lib.cleanQueryTitle(rawTitle)
  local title = (cleanTitle ~= "" and cleanTitle) or rawTitle
  local artist = (not o.hideArtist) and (m.artist or "") or ""
  local text
  if title ~= "" and artist ~= "" then
    text = o.artistFirst and (artist .. " - " .. title) or (title .. " - " .. artist)
  else
    text = title ~= "" and title or artist
  end
  if text == "" then text = noctalia.tr("common.no-title") end
  return text
end

local function rolling(text, budget, offset)
  local chars = toChars(text .. "   ")
  local n = #chars
  local start = (offset % n) + 1
  local out = {}
  for k = 0, budget - 1 do
    local idx = ((start + k - 1) % n) + 1
    out[#out + 1] = chars[idx]
  end
  return table.concat(out)
end

-- ── state / snapshot ────────────────────────────────────────────────────────

local function media()
  local ok, v = pcall(function() return noctalia.state.get("media") end)
  if ok and type(v) == "table" then return v end
  return nil
end

local visible = nil
local function setChipVisible(want)
  want = want == true
  if want ~= visible then
    visible = want
    barWidget.setVisible(want)
  end
end

-- ── render ──────────────────────────────────────────────────────────────────

local lastKey = ""
local function renderKey(m, o, shown, wave)
  return table.concat({
    m.hasPlayer and "1" or "0",
    tostring(m.playing),
    shown,
    wave or "",
    m.artUrl or "",
    (type(m.artUrl) == "string" and m.artUrl ~= "" and noctalia.fileExists(m.artUrl)) and "1" or "0",
    tostring(o.artOnly),
    tostring(o.hideArt),
    tostring(o.hideArtist),
    tostring(o.artistFirst),
    tostring(o.artSize),
    barWidget.isVertical() and "V" or "H",
  }, "|")
end

local function renderFrom(m, force)
  if not m then m = media() end
  local o = widgetOptions()
  local hasPlayer = m and m.hasPlayer or false

  -- Hide-when-no-media
  if not hasPlayer then
    if o.hideWhenNoMedia then
      setChipVisible(false)
      return
    end
    setChipVisible(true)
    local key = "empty"
    if not force and key == lastKey then return end
    lastKey = key
    barWidget.render(ui.row({ gap = GAP, align = "center" }, {
      ui.glyph({ name = "music", size = 14 }),
    }))
    return
  end
  setChipVisible(true)

  local vertical = barWidget.isVertical()
  local dim = m.playing and 1 or 0.65
  local artOk = type(m.artUrl) == "string" and m.artUrl ~= ""
    and noctalia.fileExists(m.artUrl)

  local function iconChild()
    if (not vertical) and o.hideArt then return nil end
    if artOk then
      return ui.image({
        key = "cover",
        path = m.artUrl,
        width = o.artSize,
        height = o.artSize,
        radius = math.floor(o.artSize / 4),
        fit = "cover",
        opacity = dim,
      })
    end
    return ui.glyph({
      key = "state",
      name = m.playing and glyphPause or glyphPlay,
      size = math.max(10, o.artSize - 4),
      opacity = dim,
    })
  end

  if vertical or o.artOnly then
    local children = { iconChild() }
    local key = renderKey(m, o, "icon-only", "")
    if not force and key == lastKey then return end
    lastKey = key
    barWidget.render(ui.row({ align = "center" }, children))
    return
  end

  local full = buildFull(m, o)
  if full ~= lastFull then
    lastFull = full
    scrollOffset = 0
    scrollTick = 0
  end

  local wave = m.playing and currentWave or ""
  local iconW = (not o.hideArt) and (o.artSize + GAP) or 0
  local waveW = wave ~= "" and (charCount(wave) * CHAR_PX + GAP) or 0
  local budget = math.max(8, math.floor((o.maxLength - iconW - waveW) / CHAR_PX))

  local overBudget = charCount(full) > budget
  local scrolling = overBudget and
    (o.scroll == "always" or (o.scroll == "on_hover" and hovered))

  local shown
  if overBudget then
    if o.scroll == "none" then
      shown = charPrefix(full, budget - 1) .. "…"
    else
      shown = rolling(full, budget, scrollOffset)
    end
  else
    shown = full
  end

  local key = renderKey(m, o, shown, wave)
  if not force and key == lastKey then return end
  lastKey = key

  local children = {}
  local icon = iconChild()
  if icon then children[#children + 1] = icon end

  -- Subtitle / Title label (Primary content)
  local label = ui.label({
    key = "title",
    text = shown,
    fontSize = FONT_PX,
    opacity = dim,
    maxLines = 1,
  })

  local textNode = ui.row({
    key = "textwrap",
    align = "center",
    onHover = function(state)
      local h = (state == "true")
      if h ~= hovered then
        hovered = h
        renderFrom(media(), true)
      end
    end,
  }, { label })
  children[#children + 1] = textNode

  -- Ambient audio visualizer wave (rendered after lyrics as background rhythm)
  if wave ~= "" then
    children[#children + 1] = ui.label({
      key = "wave",
      text = wave,
      fontSize = FONT_PX - 1,
      color = "primary",
      opacity = 0.55,
    })
  end

  barWidget.render(ui.row({ gap = GAP, align = "center" }, children))
end

-- ── loop ────────────────────────────────────────────────────────────────────

function update()
  local m = media()
  if not m or not m.hasPlayer then
    renderFrom(m, false)
    return
  end
  local o = widgetOptions()
  local vertical = barWidget.isVertical()
  if vertical or o.artOnly then
    renderFrom(m, false)
    return
  end

  local wave = m.playing and readAudioWaves() or ""
  local waveChanged = (wave ~= currentWave)
  if waveChanged then
    currentWave = wave
  end

  local full = buildFull(m, o)
  local iconW = (not o.hideArt) and (o.artSize + GAP) or 0
  local waveW = wave ~= "" and (charCount(wave) * CHAR_PX + GAP) or 0
  local budget = math.max(8, math.floor((o.maxLength - iconW - waveW) / CHAR_PX))
  local active = charCount(full) > budget and
    (o.scroll == "always" or (o.scroll == "on_hover" and hovered))

  local scrollStep = false
  if active then
    scrollTick = scrollTick + 1
    if scrollTick % SCROLL_TICKS == 0 then
      scrollOffset = scrollOffset + 1
      scrollStep = true
    end
  end

  if waveChanged or scrollStep or full ~= lastFull then
    renderFrom(m, true)
  end
end

noctalia.state.watch("media", function(value)
  renderFrom(value, false)
end)

noctalia.setUpdateInterval(50)
renderFrom(nil, true)

function onClick()
  noctalia.togglePanel("tranzem/media-lyrics:" .. panelIdForSize())
end
