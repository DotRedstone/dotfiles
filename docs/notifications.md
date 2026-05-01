# 系统通知 (Notifications)

本系统的通知链路基于 Freedesktop 标准，由 Noctalia 提供 UI 显示。

## 链路示意
`App -> org.freedesktop.Notifications.Notify -> Noctalia UI`

## 应用支持情况

- **QQ**: Linux QQ 已经过确认，原生支持发送 `Notify` 信号。因此**不需要**为 QQ 构建数据库桥接。
- **WeChat**: 由于原生通知不可靠，本系统使用自定义的 `wechat-notify-bridge`。

## 诊断与故障排查

### 测试通知
```bash
notify-send "Test" "Hello"
```

### 监控总线
```bash
dbus-monitor --session "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
```

### 排查流程
1. 检查 `noctalia-shell` 进程是否存活。
2. 确认应用是否在正确的显示器/工作区发出通知。
3. 检查 `mako` 或其他通知守护进程是否冲突导致抢占。
 stone
