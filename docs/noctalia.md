# Noctalia 视觉系统

Noctalia 是系统的核心外壳 (Shell) 与视觉样式管理中心，基于 Material Design 3 (MD3) 规范构建。

## 动态配色同步 (User Templates)

本系统利用 Noctalia 的 `User Templates` 功能实现全局配色方案的实时同步。

### 工作机制
- **`input_path`**: 存放于 `.dotfiles` 仓库中的 `.template` 文件。
- **`output_path`**: 渲染后的配置文件路径（通常位于 `~/.cache` 或应用配置目录）。
- **`post_hook`**: 渲染完成后执行的命令（如 `fcitx5 -r -d`）。

### 受控应用列表
| 应用 | 模板路径 | 输出路径 |
| :--- | :--- | :--- |
| **Starship** | `home/dot/starship/starship.toml.template` | `~/.cache/starship.toml` |
| **Zellij** | `home/dot/zellij/config.kdl.template` | `~/.cache/zellij.kdl` |
| **NixVim** | `home/dot/nixvim/colors.lua.template` | `~/.cache/nvim_colors.lua` |
| **Fcitx5** | `home/dot/fcitx5/templates/...` | `~/.local/share/fcitx5/themes/...` |

## MD3 设计规范

在修改模板或自定义样式时，应严格遵循 MD3 语义化 Token：
- `surface` / `on_surface`: 基础背景与文字。
- `primary` / `on_primary`: 核心强调色。
- `surface_variant` / `outline`: 边框与次要装饰。

## 维护原则

- **禁填生成文件**: 严禁将渲染后的输出文件提交至 Git 仓库，保持仓库的“干净”。
- **读写权限**: 确保 `output_path` 所在的目录在 Home Manager 中保持可写，不要将其误设为只读的 `symlinkJoin`。

相关链接：
- [Niri 桌面配置](./desktop-niri.md)
- [输入法配置](./fcitx5-rime.md)
