--!nonstrict
-- Track system power profile so the Control Center tile mirrors
-- changes made by Noctalia's built-in power settings, GameMode, or CLI.

noctalia.setUpdateInterval(2000)

local lastMode = nil
local querying = false

local function normalize(raw)
  local value = noctalia.string.trim(raw or "")
  if value == "performance" then
    return "performance"
  elseif value == "balanced-performance" then
    return "balanced-performance"
  elseif value == "balanced" then
    return "balanced"
  elseif value == "low-power" or value == "power-saver" then
    return "power-saver"
  end
  return nil
end

local function setModeIfChanged(mode)
  if mode and mode ~= lastMode then
    lastMode = mode
    noctalia.state.set("mode", mode)
  end
end

local function poll()
  if querying then
    return
  end
  querying = true
  noctalia.runAsync("powerprofilesctl get", function(result)
    querying = false
    if result.exitCode == 0 then
      setModeIfChanged(normalize(result.stdout))
    else
      local fallback = normalize(noctalia.readFile("/sys/firmware/acpi/platform_profile"))
      setModeIfChanged(fallback or "balanced")
    end
  end, 2000)
end

function update()
  poll()
end

poll()
