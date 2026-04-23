-- ---
-- Warden WezTerm Configuration
-- Description: Minimalist, high-performance terminal canvas
-- ---

local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action

-- [Visuals & Typography]
config.font = wezterm.font_with_fallback({
  { family = 'Maple Mono NF', weight = 'Regular' },
  { family = 'Noto Sans CJK SC', weight = 'Regular' },
  { family = 'Symbols Nerd Font Mono', weight = 'Regular' },
})
config.font_size = 12
config.window_background_opacity = 0.95

-- [UI & Layout]
config.enable_tab_bar = false
config.window_decorations = "NONE"
config.window_padding = {
  left = "1cell",
  right = "1cell",
  top = "0.5cell",
  bottom = "0.5cell",
}

-- [Performance & Backend]
config.front_end = "WebGpu"
config.enable_wayland = true
config.webgpu_power_preference = "HighPerformance"

-- [Theme]
config.color_scheme = 'Noctalia'

-- [SSH Domains]
config.ssh_domains = {
  { name = 'Beacon (HK)',    remote_address = 'beacon',   username = 'dot' },
  { name = 'Conduit (RN)',   remote_address = 'conduit',  username = 'dot' },
  { name = 'Hopper (Oracle)', remote_address = 'hopper',   username = 'dot' },
  { name = 'Target (Tencent)', remote_address = 'target',  username = 'dot' },
  { name = 'Repeater (Aliyun)',remote_address = 'repeater', username = 'dot' },
}

-- [Keybindings]
config.keys = {
  { key = 'S', mods = 'CTRL|SHIFT', action = act.ShowLauncher },
  { key = 'P', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
  { key = 'N', mods = 'CTRL|SHIFT', action = act.SpawnWindow },
  { key = 'W', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab{ confirm = true } },
}

return config
