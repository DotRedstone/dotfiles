-- ---
-- Module: WezTerm - Keybindings
-- Description: Custom keyboard shortcuts for terminal management
-- Scope: Home Manager
-- ---

local M = {}

function M.apply(config, wezterm)
  local act = wezterm.action

  -- [Keybindings]
  config.keys = {
    { key = 'S', mods = 'CTRL|SHIFT', action = act.ShowLauncher },
    { key = 'P', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
    { key = 'N', mods = 'CTRL|SHIFT', action = act.SpawnWindow },
    { key = 'W', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab{ confirm = true } },
    -- 复制仅在 WezTerm 自身有选区时生效，复制后清除选区。
    -- 启用鼠标上报的程序（如 Claude Code）自行处理框选复制，此时 WezTerm 选区
    -- 为空或是早先遗留的；默认 CopyTo 会用它覆盖程序刚写入的剪贴板。
    {
      key = 'C',
      mods = 'CTRL|SHIFT',
      action = wezterm.action_callback(function(window, pane)
        if window:get_selection_text_for_pane(pane) == '' then
          return
        end
        window:perform_action(act.CopyTo 'Clipboard', pane)
        window:perform_action(act.ClearSelection, pane)
      end),
    },
  }
end

return M
