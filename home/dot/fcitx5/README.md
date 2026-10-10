# Fcitx5、Rime 与动态主题

本目录把输入法环境、Fcitx5 配置、Rime 配置和 Noctalia 主题桥接分开维护。
入口是 `default.nix`，其余文件按下列边界处理。

| 需求 | 文件或目录 |
| --- | --- |
| 环境变量与启动条件 | `env.nix` |
| Fcitx5 行为和热键 | `config/behavior.nix`、`config/hotkeys.nix` |
| Rime 数据与 schema | `rime/data.nix`、`rime/schema.nix` |
| Rime 精确补丁 | `rime/patches/` |
| Lua processor | `rime/lua/` |
| Noctalia 动态主题声明 | `theme.nix`、`templates/` |
| XWayland 安全的静态回退主题 | `custom-themes/` |

重要约束：WeChat UOS 经过 XWayland / fcitx4 兼容路径；透明圆角候选框可能呈现黑角。
对应回退主题必须保持不透明、矩形。不要提交 Noctalia 运行时生成的主题目录。

验证：`home-manager build --flake .#dot@warden`；实际输入法表现还需在图形会话中验证。
