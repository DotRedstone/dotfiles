# Chrome Noctalia 主题注入

此模块将 Noctalia 生成的颜色写入 Chrome 的 Preferences 文件。

## 工作原理
1. Noctalia 的 `user-templates.toml` 会根据 `colors.json.template` 模板生成 `~/.cache/chrome-noctalia-theme/colors.json` 文件。
2. 每次颜色更新后，`chrome-theme-injector` 脚本会自动运行。
3. 脚本会解析 JSON 中的十六进制颜色，并将其转换为 Chrome Preferences 所需的格式，直接写入配置文件。

## 注意事项
- 此操作会强制重启 Chrome 进程。
- 建议保持 `settings.json` 中的 `wallhavenApiKey` 为空，使用 sops 管理。
