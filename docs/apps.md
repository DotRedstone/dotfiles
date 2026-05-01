# 应用列表 (Applications)

本页简述了系统中已配置的应用及其特殊说明。

## 通讯与协作

- **QQ**: 使用 `pkgs.qq`，已配置 `gnome-libsecret` 作为密码存储后端。支持原生桌面通知。
- **微信 (WeChat)**: 详见 [WeChat 专项说明](./wechat.md)。
- **Telegram**: 官方客户端，保持默认更新。

## 开发工具

- **Antigravity**: 高性能 AI 协作助手。采用 `no-fhs` 变体以解决在某些环境下的启动卡顿问题，禁止随意改回 FHS。
- **VSCode**: 辅助编辑器，通过 Home Manager 管理。

## 媒体与阅读

- **Firefox**: 主力浏览器，包含管理策略。
- **Chrome**: 辅助浏览器。
- **网易云音乐 (Netease)**: 使用非官方客户端，已优化 HiDPI 显示。
- **Zathura**: 极简 PDF 阅读器。

## 系统工具

- **Prism Launcher**: Minecraft 启动器。
- **MangoHud**: 游戏性能监测层。
- **Nautilus**: 系统默认文件管理器。
