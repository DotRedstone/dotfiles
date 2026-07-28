--!nonstrict
-- Track the real platform power profile so the Control Center tile mirrors
-- changes made by GameMode or the standalone gaming-power-mode command.

noctalia.setUpdateInterval(2000)

local lastMode = nil

local function normalize(raw)
  local value = noctalia.string.trim(raw or "")
  if value == "performance" then
    return "performance"
  elseif value == "full-speed" or value == "max" then
    return "full-speed"
  elseif value == "balanced-performance" then
    return "balanced-performance"
  elseif value == "balanced" then
    return "balanced"
  elseif value == "low-power" or value == "power-saver" then
    return "power-saver"
  end
  return nil
end

local function rememberedMode()
  return normalize(noctalia.readFile("/run/user/1000/gaming-power-mode/state"))
end

local function detectMode()
  local remembered = rememberedMode()
  local platformMode = normalize(noctalia.readFile("/sys/firmware/acpi/platform_profile"))

  if remembered == "full-speed" and (platformMode == nil or platformMode == "performance") then
    return "full-speed"
  elseif platformMode then
    return platformMode
  end

  return remembered or "unknown"
end

local function publish()
  local mode = detectMode()
  if mode ~= lastMode then
    lastMode = mode
    noctalia.state.set("mode", mode)
  end
end

function update()
  publish()
end

publish()
