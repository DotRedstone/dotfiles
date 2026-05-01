# ---
# Module: NixVim - UI Plugins
# Description: Visual interface enhancements (Lualine, Bufferline, Noice, etc.)
# Scope: Home Manager
# ---

{ ... }: {
  programs.nixvim.plugins = {
    lualine = {
      enable = true;
      settings = {
        options = {
          theme = "catppuccin";
          globalstatus = true;
          component_separators = { left = ""; right = ""; };
          section_separators = { left = ""; right = ""; };
          disabled_filetypes.statusline = [ "dashboard" "alpha" "starter" ];
        };
        sections = {
          lualine_a = [{ __unkeyed-1 = "mode"; separator.right = ""; }];
          lualine_b = [ "branch" "diff" ];
          lualine_c = [{
            __unkeyed-1 = "filename";
            path = 1;
            symbols = { modified = " ●"; readonly = " "; unnamed = "[No Name]"; };
          }];
          lualine_x = [ "diagnostics" "encoding" "filetype" ];
          lualine_y = [ "progress" ];
          lualine_z = [{ __unkeyed-1 = "location"; separator.left = ""; }];
        };
      };
    };

    bufferline = {
      enable = true;
      settings.options = {
        diagnostics = "nvim_lsp";
        always_show_bufferline = true;
        separator_style = "slant";
        offsets = [{
          filetype = "neo-tree";
          text = "Explorer";
          highlight = "Directory";
          text_align = "left";
        }];
      };
    };

    noice = {
      enable = true;
      settings = {
        lsp.override = {
          "vim.lsp.util.convert_input_to_markdown_lines" = true;
          "vim.lsp.util.stylize_markdown" = true;
        };
        presets = {
          bottom_search = true;
          command_palette = true;
          long_message_to_split = true;
          inc_rename = false;
          lsp_doc_border = true;
        };
      };
    };

    smear-cursor = {
      enable = true;
      settings = {
        smear_between_buffers = true;
        smear_between_neighbor_lines = true;
        smear_to_cmd = true;
        scroll_buffer_space = true;
        hide_target_hack = true;
        legacy_computing_symbols_support = false;
        stiffness = 0.72;
        trailing_stiffness = 0.38;
        trailing_exponent = 2;
        distance_stop_animating = 0.08;
        time_interval = 17;
        delay_animation_start = 3;
        max_length = 28;
        color_levels = 16;
        cursor_color.__raw = "nil";
        normal_bg.__raw = "nil";
        transparent_bg_fallback_color = "303030";
      };
    };

    notify.enable = true;
    dressing.enable = true;
    nui.enable = true;
    web-devicons.enable = true;
    illuminate.enable = true;
    aerial.enable = true;

    indent-blankline = {
      enable = true;
      settings = {
        indent.char = "│";
        scope = { enabled = true; show_start = false; show_end = false; };
        exclude.filetypes = [
          "help" "alpha" "dashboard" "neo-tree" "Trouble" "lazy" "mason" "notify"
        ];
      };
    };
  };
}
