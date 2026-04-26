# ---
# Module: Nixvim Theme
# Description: Catppuccin with automatic light/dark detection
# ---

{ ... }: {
  programs.nixvim.colorschemes.catppuccin = {
    enable = true;
  };

  programs.nixvim.extraConfigLua = ''
    -- 1. 加载 Noctalia 生成的配色文件
    local palette_path = vim.fn.expand("~/.cache/nvim_colors.lua")
    local custom_palette = {}
    if vim.fn.filereadable(palette_path) == 1 then
      custom_palette = dofile(palette_path)
    end

    -- 2. 自动亮度检测函数 (用于切换背景模式)
    local function detect_system_theme()
      local theme_file = vim.fn.expand("~/.local/state/quickshell/user/generated/colors.json")
      if vim.fn.filereadable(theme_file) == 1 then
        local content = table.concat(vim.fn.readfile(theme_file), "\n")
        local bg_color = content:match('"background":%s*"(#[%w]+)"')
        if bg_color then
          local hex = bg_color:gsub("#", "")
          local r = tonumber(hex:sub(1, 2), 16) or 0
          local g = tonumber(hex:sub(3, 4), 16) or 0
          local b = tonumber(hex:sub(5, 6), 16) or 0
          local brightness = (r * 299 + g * 587 + b * 114) / 1000
          vim.o.background = brightness > 128 and "light" or "dark"
          return true
        end
      end
      return false
    end

    -- 3. 应用配色覆盖与插件集成
    require("catppuccin").setup({
      transparent_background = true,
      show_end_of_buffer = false,
      integrations = {
        telescope = { enabled = true },
        neotree = true,
        treesitter = true,
        cmp = true,
        flash = true,
        notify = true,
        which_key = true,
      },
      color_overrides = {
        mocha = {
          base = custom_palette.base,
          mantle = custom_palette.mantle,
          crust = custom_palette.crust,
          text = custom_palette.text,
        },
        latte = {
          base = custom_palette.base,
          mantle = custom_palette.mantle,
          crust = custom_palette.crust,
          text = custom_palette.text,
        },
      }
    })

    -- 4. 执行检测并应用具体的 Catppuccin 子主题
    if not detect_system_theme() then
      vim.o.background = "dark"
    end

    if vim.o.background == "light" then
      vim.cmd.colorscheme("catppuccin-latte")
    else
      vim.cmd.colorscheme("catppuccin-mocha")
    end
  '';
}
