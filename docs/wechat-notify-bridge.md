# 微信通知桥 (WeChat Notify Bridge)

WeChat UOS 在 Linux 环境下的原生通知系统非常不可靠，经常出现漏发或无法唤起桌面通知 daemon 的情况。

## 桥接原理

为了解决此问题，本系统引入了一个通知桥：
1. **监听**: 监控微信的消息数据库（SQLite）。
2. **解密**: 获取 SQLCipher 密钥（WeChat 在运行时会将其缓存在内存中）。
3. **分发**: 提取新消息内容并调用 `notify-send` 触发系统通知。

## 技术细节

- **ptrace_scope**: 内核的 `kernel.yama.ptrace_scope` 设置会影响 bridge 获取 SQLCipher 密钥的能力。如果无法发现密钥，请检查此项安全设置。
- **安全约束**: 
  - **严禁**打印或泄露 SQLCipher 密钥。
  - **严禁**将运行时的缓存文件（如解密后的消息片段）提交到 Git 仓库。

## 与 QQ 的区别

- **Linux QQ**: 已经能够正常调用 D-Bus 接口 `org.freedesktop.Notifications.Notify` 发送通知。
- **策略**: 既然 QQ 已经原生支持，则**不需要**也不应该为 QQ 编写数据库桥接工具。应优先使用 Freedesktop/Portal 标准接口。
