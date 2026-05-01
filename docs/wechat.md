# 微信集成 (WeChat)

WeChat UOS 在 Linux 下由于兼容性层限制，存在多项已知问题，本仓库提供了针对性优化。

## 输入法适配 (IME)

微信运行在 XWayland 下并使用 fcitx4 兼容路径。
- **问题**: 透明圆角输入框会出现黑边/黑角。
- **方案**: 必须配合使用 **Inflex (Rectangular)** 系列主题。
- **原则**: 严禁为了微信而降低全局桌面的透明度或视觉质量。

## 通知桥接 (Notify Bridge)

由于官方通知不可靠，系统启动了 `wechat-notify-bridge`。
- **原理**: 监听 SQLite 数据库变化 -> 发现消息 -> 触发 `notify-send`。
- **权限**: 依赖 `ptrace_scope` 权限以发现 SQLCipher 密钥。
- **安全禁令**:
  - 禁止在日志或终端打印 SQLCipher 密钥。
  - 禁止提交运行时的密钥缓存 (`runtime key cache`)。

## 配置建议
- 微信窗口配置了特定的窗口规则（不透明度等），详情参见 `docs/desktop-niri.md`。
- 建议定期清理微信庞大的运行时缓存。
