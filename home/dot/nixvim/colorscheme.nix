# ---
# Module: NixVim - Colorscheme
# Description: Catppuccin theme configuration with Noctalia dynamic palette integration
# Scope: Home Manager
# ---

{ ... }: {
  programs.nixvim = {
    colorschemes.catppuccin.enable = true;

    extraConfigLuaPre = ''
      local function read_noctalia_palette()
        local palette_path = vim.fn.expand("~/.cache/nvim_colors.lua")
        if vim.fn.filereadable(palette_path) == 1 then
          local ok, palette = pcall(dofile, palette_path)
          if ok and type(palette) == "table" then
            return palette
          end
        end
        return {}
      end

      local function detect_system_theme()
        local theme_file = vim.fn.expand("~/.local/state/quickshell/user/generated/colors.json")
        if vim.fn.filereadable(theme_file) ~= 1 then
          return false
        end

        local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(theme_file), "\n"))
        if not ok or type(decoded) ~= "table" or type(decoded.background) ~= "string" then
          return false
        end

        local hex = decoded.background:gsub("#", "")
        if #hex < 6 then
          return false
        end

        local r = tonumber(hex:sub(1, 2), 16) or 0
        local g = tonumber(hex:sub(3, 4), 16) or 0
        local b = tonumber(hex:sub(5, 6), 16) or 0
        local brightness = (r * 299 + g * 587 + b * 114) / 1000
        vim.o.background = brightness > 128 and "light" or "dark"
        return true
      end

      _G.apply_noctalia_catppuccin = function()
        local custom_palette = read_noctalia_palette()

        require("catppuccin").setup({
          background = {
            light = "latte",
            dark = "mocha",
          },
          transparent_background = true,
          show_end_of_buffer = false,
          integrations = {
            aerial = true,
            blink_cmp = true,
            flash = true,
            gitsigns = true,
            illuminate = true,
            indent_blankline = {
              enabled = true,
            },
            lsp_trouble = true,
            lualine = true,
            markdown = true,
            mason = false,
            native_lsp = {
              enabled = true,
              virtual_text = {
                errors = { "italic" },
                hints = { "italic" },
                warnings = { "italic" },
                information = { "italic" },
              },
              underlines = {
                errors = { "underline" },
                hints = { "underline" },
                warnings = { "underline" },
                information = { "underline" },
              },
            },
            neotree = true,
            noice = true,
            notify = true,
            rainbow_delimiters = true,
            snacks = true,
            telescope = {
              enabled = true,
            },
            treesitter = true,
            treesitter_context = true,
            which_key = true,
          },
          color_overrides = {
            all = {
              base = custom_palette.base,
              mantle = custom_palette.mantle,
              crust = custom_palette.crust,
              text = custom_palette.text,
              subtext0 = custom_palette.subtext0,
              subtext1 = custom_palette.subtext1,
              surface0 = custom_palette.surface0,
              surface1 = custom_palette.surface1,
              surface2 = custom_palette.surface2,
              overlay0 = custom_palette.overlay0,
              overlay1 = custom_palette.overlay1,
              overlay2 = custom_palette.overlay2,
              blue = custom_palette.blue,
              cyan = custom_palette.cyan,
              green = custom_palette.green,
              magenta = custom_palette.magenta,
              red = custom_palette.red,
              yellow = custom_palette.yellow,
              rosewater = custom_palette.tertiary,
              flamingo = custom_palette.primary,
              pink = custom_palette.tertiary,
              mauve = custom_palette.primary,
              maroon = custom_palette.error,
              peach = custom_palette.secondary,
              teal = custom_palette.secondary,
              lavender = custom_palette.primary,
              on_primary = custom_palette.on_primary,
              on_secondary = custom_palette.on_secondary,
              on_tertiary = custom_palette.on_tertiary,
              on_surface = custom_palette.on_surface,
              primary_container = custom_palette.primary_container,
              secondary_container = custom_palette.secondary_container,
              tertiary_container = custom_palette.tertiary_container,
            },
          },
          custom_highlights = function(colors)
            return {
              LineNr = { fg = colors.secondary_container },
              CursorLineNr = { fg = colors.primary, style = { "bold" } },
              Visual = { bg = colors.surface2, style = { "underline" } },
              PmenuSel = { bg = colors.surface2, style = { "bold" } },
              Pmenu = { fg = colors.text, bg = colors.surface0 },
              MatchParen = { bg = colors.surface2, style = { "bold", "underline" } },
              Comment = { fg = colors.subtext0, style = { "italic" } },
              Search = { bg = colors.surface1 },
              IncSearch = { bg = colors.surface2 },
              UnexpectedDelimiters = { fg = colors.error },
            }
          end,
        })

        if not detect_system_theme() then
          vim.o.background = "dark"
        end

        vim.cmd.colorscheme(vim.o.background == "light" and "catppuccin-latte" or "catppuccin-mocha")

        -- [Smear Cursor]
        local smear_ok, smear_cursor = pcall(require, "smear-cursor")
        if smear_ok then
          smear_cursor.setup({
            cursor_color = custom_palette.primary or "#ffffff",
            normal_bg = custom_palette.base or "#000000",
            stiffness = 0.72,
            trailing_stiffness = 0.38,
            trailing_exponent = 2,
            distance_stop_animating = 0.08,
            time_interval = 17,
            delay_animation_start = 3,
            max_length = 28,
            color_levels = 16,
            smear_between_buffers = true,
            smear_between_neighbor_lines = true,
            smear_to_cmd = true,
            scroll_buffer_space = true,
            hide_target_hack = true,
            legacy_computing_symbols_support = false,
            transparent_bg_fallback_color = "303030",
          })
        end
      end

      _G.apply_noctalia_catppuccin()
    '';

    extraConfigLuaPost = ''
      local noctalia_theme_group = vim.api.nvim_create_augroup("dot_noctalia_theme", { clear = true })
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = noctalia_theme_group,
        pattern = {
          vim.fn.expand("~/.cache/nvim_colors.lua"),
          vim.fn.expand("~/.local/state/quickshell/user/generated/colors.json"),
        },
        callback = function() _G.apply_noctalia_catppuccin() end,
      })
    '';
  };
}
