# 微信通知桥 (WeChat Notify Bridge)

WeChat UOS 的原生通知在此桌面环境下可能漏发，因此使用用户级通知桥补充系统通知。

## 桥接原理

通知桥按以下步骤处理新消息：
1. **监听**: 监控微信的本地 SQLCipher 数据库。
2. **解密**: 获取 SQLCipher 密钥（WeChat 在运行时会将其缓存在内存中）。
3. **分发**: 提取新消息内容并调用 `notify-send` 触发系统通知。

## 技术细节

- **ptrace_scope**: 内核的 `kernel.yama.ptrace_scope` 设置会影响 bridge 获取 SQLCipher 密钥的能力。如果无法发现密钥，请检查此项安全设置。
- **安全约束**: 
  - **严禁**打印或泄露 SQLCipher 密钥。
  - **严禁**将运行时的缓存文件（如解密后的消息片段）提交到 Git 仓库。

## 与 QQ 的区别

- **Linux QQ**: 已经能够正常调用 D-Bus 接口 `org.freedesktop.Notifications.Notify` 发送通知。
- **策略**: QQ 优先使用原生 Freedesktop/Portal 通知接口，不增加数据库桥接工具。
