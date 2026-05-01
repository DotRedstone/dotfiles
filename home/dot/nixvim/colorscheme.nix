# ---
# Module: NixVim - Colorscheme
# Description: Catppuccin theme configuration with Noctalia dynamic palette integration
# Scope: Home Manager
# ---

{ ... }: {
  programs.nixvim = {
    colorschemes.catppuccin.enable = true;

    extraConfigLuaPost = ''
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

      local function apply_noctalia_catppuccin()
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
            },
          },
        })

        if not detect_system_theme() then
          vim.o.background = "dark"
        end

        vim.cmd.colorscheme(vim.o.background == "light" and "catppuccin-latte" or "catppuccin-mocha")
      end

      apply_noctalia_catppuccin()

      local noctalia_theme_group = vim.api.nvim_create_augroup("dot_noctalia_theme", { clear = true })
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = noctalia_theme_group,
        pattern = {
          vim.fn.expand("~/.cache/nvim_colors.lua"),
          vim.fn.expand("~/.local/state/quickshell/user/generated/colors.json"),
        },
        callback = apply_noctalia_catppuccin,
      })
    '';
  };
}
