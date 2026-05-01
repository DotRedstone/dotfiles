# 编辑器 (NixVim)

本系统的编辑器是基于 [NixVim](https://github.com/nix-community/nixvim) 构建的 Neovim。

## 模块结构

- **`options.nix`**: 全局 Neovim 选项与行为设置。
- **`keymaps.nix`**: 核心快捷键，包括仿 Mac 的 Super 快捷键映射。
- **`plugins.nix`**: 插件管理，提供类似 LazyVim 的全功能体验。
- **`theme.nix`**: 色彩主题配置，通过 Noctalia Template 实现配色同步。
- **`packages.nix`**: 依赖的外部二进制文件（LSP, Formatters, Tree-sitter）。

## 核心插件

- **UI**: `lualine`, `bufferline`, `neo-tree`, `noice`, `which-key`。
- **搜索**: `telescope`, `flash`。
- **代码**: `treesitter`, `lsp` (nil_ls, pyright, rust_analyzer 等), `none-ls` (格式化与诊断)。
- **AI**: `copilot-lua`。

## 常用快捷键 (Leader = Space)

- `<leader>e`: 切换目录树 (`Neo-tree`)。
- `<leader><space>`: 搜索文件 (`Telescope`)。
- `<leader>/`: 全局搜索文本。
- `gd`: 跳转至定义。
- `K`: 查看悬浮文档。
- `<leader>ca`: 执行代码操作 (Code Action)。
- `s`: 启动快速跳转 (`Flash`)。
