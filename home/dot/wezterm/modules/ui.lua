local M = {}

function M.apply(config, _)
  -- [UI & Layout]
  config.enable_tab_bar = false
  config.window_decorations = "NONE"
  config.window_padding = {
    left = "1cell",
    right = "1cell",
    top = "0.5cell",
    bottom = "0.5cell",
  }
end

return M
