# 微信集成 (WeChat)

WeChat UOS 在当前桌面环境（Niri + Noctalia）下存在特定的显示与通知问题，本仓库通过特定的 Workaround 实现了深度集成。

## 输入法适配 (IME)

微信运行在 XWayland 模式下并使用 fcitx4 兼容路径。
- **问题**: 使用带透明度或圆角的 Fcitx5 主题（如 Mellow 系列）时，候选框会出现黑色方块背景。
- **对策**: 在微信中应使用 **Inflex (Rectangular)** 系列直角主题。
- **原则**: 严禁为了照顾微信而降低全局系统的透明度或毛玻璃质量。

## 通知桥接 (WeChat Notify Bridge)

由于官方微信客户端无法可靠触发系统通知，系统配置了自定义的桥接服务。

### 工作原理
- **监听**: 系统运行 `wechat-notify-bridge` 用户级服务。
- **检测**: 该服务通过监听微信本地 SQLite 数据库的变化来获取新消息。
- **解密**: 自动从微信进程中寻找 SQLCipher 密钥。

### 核心限制
- **`ptrace_scope`**: 系统内核设置会影响密钥提取。
- **安全性**: 
  - **严禁**在日志中打印 SQLCipher 密钥内容。
  - **严禁**将解密后的运行时密钥缓存提交至 Git。

## 系统服务
微信通知桥通过 Systemd User Service 管理：
- **服务名**: `wechat-notify-bridge.service`
- **操作**: `systemctl --user status wechat-notify-bridge`

相关链接：
- [系统通知](./notifications.md)
- [输入法配置](./fcitx5-rime.md)
