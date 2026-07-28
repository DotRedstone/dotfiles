--!nonstrict
-- Control Center tile for the local gaming-power-mode dispatcher.

local mode = noctalia.state.get("mode") or "balanced"
local busy = false
local cycle = { "power-saver", "balanced", "balanced-performance", "performance" }

local function commandAvailable()
  return noctalia.commandExists("gaming-power-mode")
end

local function labelFor(currentMode)
  if currentMode == "performance" then
    return "性能模式"
  elseif currentMode == "balanced-performance" then
    return "均衡性能"
  elseif currentMode == "full-speed" then
    return "满速模式"
  elseif currentMode == "power-saver" then
    return "省电模式"
  elseif currentMode == "unknown" then
    return "性能调度"
  end
  return "均衡模式"
end

local function render()
  local available = commandAvailable()
  shortcut.setLabel(if busy then "切换中..." else labelFor(mode))
  shortcut.setIcon("bolt", "battery-2")
  shortcut.setActive(mode == "performance" or mode == "balanced-performance" or mode == "full-speed")
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
  elseif target == "balanced-performance" then
    return "balanced-performance"
  elseif target == "power-saver" or target == "low-power" or target == "quiet" then
    return "power-saver"
  end
  return "balanced"
end

local function nextMode(currentMode)
  for index = 1, #cycle do
    if cycle[index] == currentMode then
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
  setMode("full-speed")
end
