--!nonstrict
-- Control Center tile for the local gaming-power-mode dispatcher.

local mode = noctalia.state.get("mode") or "balanced"
local busy = false
local cycle = { "power-saver", "balanced", "performance" }

local function commandAvailable()
  return noctalia.commandExists("gaming-power-mode")
end

local function labelFor(currentMode)
  if currentMode == "power-saver" or currentMode == "low-power" then
    return "节能模式"
  elseif currentMode == "performance" then
    return "性能模式"
  elseif currentMode == "balanced-performance" then
    return "均衡性能"
  elseif currentMode == "full-speed" then
    return "满速模式"
  elseif currentMode == "unknown" then
    return "性能调度"
  end
  return "均衡模式"
end

local function iconFor(currentMode)
  if currentMode == "power-saver" or currentMode == "low-power" then
    return "leaf", "battery"
  elseif currentMode == "performance" then
    return "bolt", "cpu"
  elseif currentMode == "full-speed" then
    return "flame", "zap"
  end
  return "gauge", "battery-2"
end

local function render()
  local available = commandAvailable()
  local primaryIcon, fallbackIcon = iconFor(mode)
  shortcut.setLabel(if busy then "切换中..." else labelFor(mode))
  shortcut.setIcon(primaryIcon, fallbackIcon)
  shortcut.setActive(mode == "performance" or mode == "full-speed" or mode == "power-saver" or mode == "low-power")
  shortcut.setEnabled(available and not busy)
end

local function applyMode(nextMode)
  if type(nextMode) == "string" then
    mode = nextMode
    render()
  end
end

noctalia.state.watch("mode", applyMode)
render()

local function stateForTarget(target)
  if target == "full-speed" then
    return "full-speed"
  elseif target == "performance" then
    return "performance"
  elseif target == "power-saver" or target == "low-power" then
    return "power-saver"
  end
  return "balanced"
end

local function nextMode(currentMode)
  local normalized = if currentMode == "low-power" then "power-saver" else currentMode
  for index = 1, #cycle do
    if cycle[index] == normalized then
      return cycle[(index % #cycle) + 1]
    end
  end
  return "balanced"
end

local function setMode(target)
  if busy then
    return
  end

  busy = true
  render()

  noctalia.runAsync("gaming-power-mode " .. target, function(result)
    busy = false
    if result.exitCode == 0 then
      mode = stateForTarget(target)
      noctalia.state.set("mode", mode)
    else
      local message = noctalia.string.trim(result.stderr or "")
      if message == "" then
        message = "gaming-power-mode 返回失败"
      end
      noctalia.notifyError("性能模式切换失败", message)
    end
    render()
  end, 10000)
end

function onClick()
  setMode(nextMode(mode))
end

function onRightClick()
  if mode == "full-speed" then
    setMode("balanced")
  else
    setMode("full-speed")
  end
end
