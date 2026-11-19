-- ---
-- Module: WezTerm - Scroll
-- Description: Scrollback depth, wheel step size, and scroll position feedback
-- Scope: Home Manager
-- ---

local M = {}

function M.apply(config, wezterm)
  local act = wezterm.action

  -- [Scrollback]
  -- 默认 3500 行偏浅，翻日志容易直接顶到缓冲边界。
  config.scrollback_lines = 10000

  -- [Wheel Step]
  -- WezTerm 只按整行滚动，没有像素级平滑滚动；滚轮步长在当前版本也不再是
  -- 配置项（wheel_scroll_multiplier 与 wheel_scroll_speed 均非有效字段）。
  -- alternate_buffer 对应 less / vim / htop 这类全屏程序，默认 3 行一跳，
  -- 逐行阅读时不好定位，这里降为 1 行。
  config.alternate_buffer_wheel_scroll_speed = 1
  config.mouse_wheel_scrolls_tabs = false

  -- 普通缓冲区仍保留默认步长，另给 Shift+滚轮 提供逐行微调。
  -- 不覆盖无修饰键的 WheelUp/WheelDown：那会抢走全屏程序的鼠标滚动。
  config.mouse_bindings = {
    { event = { Down = { streak = 1, button = { WheelUp = 1 } } }, mods = 'SHIFT', action = act.ScrollByLine(-1) },
    { event = { Down = { streak = 1, button = { WheelDown = 1 } } }, mods = 'SHIFT', action = act.ScrollByLine(1) },
  }

  -- [Position Feedback]
  -- 滚动条用来判断当前处在缓冲区的位置，避免翻动后无法确认漏读。
  config.enable_scroll_bar = true
end

return M
