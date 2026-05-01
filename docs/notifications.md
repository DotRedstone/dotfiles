# 系统通知 (Notifications)

本系统的桌面通知遵循标准的 Freedesktop `Notify` 协议，由 Noctalia 提供 UI 显示。

## 链路流程

`应用程序 -> D-Bus (org.freedesktop.Notifications) -> Noctalia UI`

## 诊断与测试

### 1. 手动验证
运行以下命令验证通知 UI 是否正常工作：
```bash
notify-send "测试通知" "Hello, this is a test notification."
```

### 2. 总线监控 (D-Bus)
通过监控总线流量来判断应用是否确实发送了通知：
```bash
dbus-monitor --session "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
```

## 应用适配情况

- **Linux QQ**: 已经原生支持 `Notify` 协议。无需额外桥接，通知直接由 Noctalia 捕获。
- **WeChat**: 官方通知机制不可靠。通过 `wechat-notify-bridge` 将数据库消息转换为系统通知信号。

## 故障排查

1. **通知不显示**:
   - 检查 `noctalia-shell` 进程是否存活。
   - 确认没有其他通知守护进程（如 `mako`, `dunst`）正在运行并抢占 D-Bus 接口。
2. **WeChat 通知失效**:
   - 检查 `systemctl --user status wechat-notify-bridge`。
   - 检查微信数据库文件是否因持久化配置错误而变得不可读。

相关链接：
- [微信集成](./wechat.md)
- [Noctalia 视觉系统](./noctalia.md)
