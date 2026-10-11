# 微信集成 (WeChat)

WeChat UOS 在 Niri + Noctalia 环境下有输入法候选框显示和系统通知问题。本仓库分别提供主题兼容方案与通知桥服务。

## 输入法适配 (IME)

微信运行在 XWayland 模式下并使用 fcitx4 兼容路径。
- **问题**: 使用带透明度或圆角的 Fcitx5 主题（如 Mellow 系列）时，候选框会出现黑色方块背景。
- **对策**: 在微信中应使用 **Inflex (Rectangular)** 系列直角主题。
- **原则**: 严禁为了照顾微信而降低全局系统的透明度或毛玻璃质量。

## 通知桥接

`wechat-notify-bridge.service` 是用户级服务，用于补充微信未发出的系统通知。
其数据来源、SQLCipher 密钥处理、安全边界和故障检查统一记录在
[微信通知桥](./wechat-notify-bridge.md)。查看服务状态：

```bash
systemctl --user status wechat-notify-bridge
```

相关链接：
- [系统通知](./notifications.md)
- [输入法配置](./fcitx5-rime.md)
