-- ---
-- Module: WezTerm - Performance
-- Description: OpenGL backend and Wayland enablement
-- Scope: Home Manager
-- ---

local M = {}

function M.apply(config, _)
  -- [Performance & Backend]
  -- Use OpenGL for instantaneous config & theme reloading without pipeline teardown
  config.front_end = "OpenGL"
  config.enable_wayland = true
  config.webgpu_power_preference = "HighPerformance"
end

return M
