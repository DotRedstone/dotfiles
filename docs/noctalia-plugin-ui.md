# Noctalia 本地插件维护

本仓库当前使用 Noctalia v5 插件结构。本地插件位于
[`home/dot/noctalia/plugins/`](../home/dot/noctalia/plugins/)；
[插件同步模块](../home/dot/noctalia/plugins.nix)负责注册来源并启用所需插件。
旧的 QML `Panel.qml`、`Main.qml` 和 `_shared` 组件方案不属于当前仓库实现。

## 已有插件

`gaming_power` 是当前仓库中的本地插件：

| 文件 | 职责 |
| --- | --- |
| `plugin.toml` | 插件身份、Noctalia 版本和入口声明 |
| `service.luau` | 读取系统性能状态并发布插件状态 |
| `shortcut.luau` | 显示控制中心快捷项并调用受限的性能切换命令 |
| `translations/` | 界面文字的中英文翻译 |

性能模式的实际控制逻辑由系统侧命令维护。插件只读取状态并调用该命令，
不复制系统权限或设备控制逻辑。

## 新插件边界

- 先确认现有官方或社区插件能否满足需求。只有本机特有的集成需要留在
  `home/dot/noctalia/plugins/`；可复用的完整插件达到独立维护条件时，
  按根目录 [AGENTS.md](../AGENTS.md) 的项目边界迁出。
- 在 `plugin.toml` 声明与当前 Noctalia API 相符的入口。服务、快捷项和翻译
  各自维护职责；不要把系统配置或密钥复制到插件中。
- 界面颜色使用 Noctalia 的语义 token。错误提示不显示 token、原始响应、
  使用记录或其他个人数据。
- 增加插件后检查同步模块的来源与启用列表，运行
  `home-manager build --flake .#dot@warden`。实际加载、交互和权限行为
  仍需在 Noctalia 会话中验证。

目录职责和服务边界见
[Noctalia Shell 配置](../home/dot/noctalia/README.md)。
