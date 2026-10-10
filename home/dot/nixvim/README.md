# NixVim 模块

`default.nix` 只组合 NixVim 的原子模块。这里是 Nix 声明式 Neovim 配置的唯一来源；
不要再添加 Lua 配置目录或恢复旧的单体插件表。

| 范畴 | 文件 |
| --- | --- |
| 启用、编辑器别名与基础依赖 | `core.nix`、`packages.nix` |
| 通用行为 | `options.nix`、`autocmds.nix`、`diagnostics.nix` |
| 快捷键 | `keymaps.nix` |
| 配色 | `colorscheme.nix`、`theme.nix`、`colors.lua.template` |
| 插件分类 | `plugins/default.nix` 与 `plugins/*.nix` |

插件新增或调整要放进现有最贴近的分类；只有新类别确实独立时才新建一个
`plugins/<category>.nix` 并在 `plugins/default.nix` 导入。键位优先归属
`keymaps.nix`，不要将无关键位塞进插件文件。

验证：`home-manager build --flake .#dot@warden`。
