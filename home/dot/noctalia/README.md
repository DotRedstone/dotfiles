# Noctalia Shell 配置

本目录维护 Noctalia 的声明式启动包装、静态 TOML、插件同步、中文翻译和本地插件。
Noctalia 的一部分插件开关与 materialized 文件由应用在运行时维护，不能把这些状态
误当作声明式源文件。

| 范畴 | 位置 |
| --- | --- |
| 导入入口 | `default.nix` |
| 程序包装与 API 密钥注入 | `config.nix` |
| 静态 shell 配置 | `config/*.toml` |
| systemd user service 与链接 | `service.nix`、`links.nix` |
| 插件源、启用列表和幂等同步 | `plugins.nix` |
| 本地插件源 | `plugins/` |
| 第三方插件覆写 | `overrides/` |
| 中文翻译覆写 | `translations/` |
| 给界面调用的小脚本 | `scripts.nix`、`scripts/` |

使用 MD3 语义 token（如 `surface`、`primary`、`outline`）而不是为单个插件硬编码
颜色。密钥始终从 sops-nix 生成的只读路径读取，不进 TOML、不进 Git、不出现在日志中。

验证：`home-manager build --flake .#dot@warden`；插件同步和界面表现需要重启
`noctalia.service` 后在实际会话确认。
