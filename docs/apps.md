# 应用列表 (Applications)

本页记录了系统中常用应用的配置来源及其特定的使用建议。

## 通讯应用

- **QQ**: 
  - 包装版本: `pkgs.qq`
  - 参数: 强制启用 `--password-store=gnome-libsecret` 以支持密码记忆。
- **微信 (WeChat)**: 
  - 详情参见 [WeChat 专项说明](./wechat.md)。
- **Telegram**: 
  - 包含 `AyuGramDesktop` 等变体，支持消息撤回可见等特性。

## 生产力与开发

- **Antigravity**: 
  - **核心限制**: 使用 `no-fhs` 变体以避免在无状态根目录下由于 FHS 环境导致的加载卡顿。
  - 参数: 已通过 Wrapper 注入 `--password-store=gnome-libsecret`。
- **VSCode**: 全功能编辑器，作为 NixVim 的辅助。
- **Firefox**: 
  - **持久化**: 个人资料 (Profile) 位于 `.mozilla` 目录。
- **Chrome**: 
  - 已通过 `modules/system/chrome.nix` 注入企业级管理策略（如禁用部分隐私追踪）。

## 工具与媒体

- **Yazi**: 
  - 命令行文件管理器。在 Shell 中通过别名 `y` 启动，支持退出时自动切换目录。
- **Zathura**: 基于键盘驱动的 PDF 阅读器。
- **Prism Launcher**: Minecraft 启动器，持久化路径已配置。
- **MangoHud**: 游戏性能监测层，常用于 Steam 应用。

## 系统实用工具

- **Nautilus**: 默认 GUI 文件管理器。
- **Clipper**: 集成在 Noctalia Shell 中的剪贴板管理器，可通过 `Mod+B` 调出。

相关链接：
- [微信集成](./wechat.md)
- [终端 (WezTerm)](./terminal-wezterm.md)
- [编辑器 (NixVim)](./editor-nixvim.md)
