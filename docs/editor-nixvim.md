# 编辑器 (NixVim)

本系统的编辑器基于 [NixVim](https://github.com/nix-community/nixvim) 构建，提供了类似 LazyVim 的现代编辑体验，同时深度集成了 NixOS 生态。

## 核心快捷键 (Leader = Space)

### 文件与系统
| 按键 | 功能 |
| :--- | :--- |
| `<leader>e` | 切换文件浏览器 (Explorer) |
| `<leader>f f` | 查找文件 |
| `<leader>f g` | 搜索文本 (Grep) |
| `<leader>f r` | 查看最近打开的文件 |
| `<leader>w` | 保存文件 |
| `<leader>q` | 退出 |

### 代码与 LSP
| 按键 | 功能 |
| :--- | :--- |
| `gd` | 跳转至定义 (Goto Definition) |
| `gr` | 查看引用 (References) |
| `K` | 悬浮显示文档 (Hover) |
| `<leader>ca` | 执行代码操作 (Code Action) |
| `<leader>cf` | 格式化当前文件 |
| `<leader>rn` | 变量重命名 |
| `s` | 启动 Flash 快速跳转 |

### Git 协作
| 按键 | 功能 |
| :--- | :--- |
| `<leader>gg` | 启动 Lazygit |
| `<leader>ghs` | 暂存当前 Hunk |
| `<leader>ghr` | 重置当前 Hunk |

## 核心插件

- **UI**: `lualine`, `bufferline`, `neo-tree`, `noice` (消息美化), `which-key`。
- **功能**: `telescope` (搜索), `flash` (导航), `snacks` (综合工具集), `persistence` (会话恢复)。
- **编码**: `treesitter` (高亮), `lsp` (LSP 支持), `conform-nvim` (格式化), `lint` (诊断), `blink-cmp` (极致补全)。
- **AI**: `copilot-lua` & `blink-copilot`。

## 配色方案

NixVim 的配色通过 Noctalia 模板系统同步。
- 模板文件: `home/dot/nixvim/colors.lua.template`
- 渲染路径: `~/.cache/nvim_colors.lua`
- 该文件会被 NixVim 自动加载以确保编辑器配色与全局桌面一致。

相关链接：
- [Noctalia 视觉系统](./noctalia.md)
- [终端 (WezTerm)](./terminal-wezterm.md)
