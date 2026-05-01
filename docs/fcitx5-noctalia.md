# Fcitx5 与 Noctalia 主题同步

本系统通过 Noctalia 动态生成输入法主题，确保输入法候选框的配色与桌面环境保持一致。

## 配置结构

- **Fcitx5**: 位于 `home/dot/fcitx5/`，采用模块化拆分。
- **Rime**: 位于 `home/dot/fcitx5/rime/`。
  - `patches/`: 包含 `ascii-composer.nix`, `keybindings.nix` 等原子化补丁。
  - `lua/`: Rime Lua 扩展插件。

## 主题同步机制

Noctalia 使用 `user templates` 功能来监听系统调色盘的变化。当壁纸或配色方案改变时，Noctalia 会重新渲染位于 `~/.local/share/fcitx5/themes` 下的主题文件。

## 主题类型

系统预设了四种主要的 Noctalia Fcitx5 主题，分为两类定位：

### 1. Mellow 系列 (mellow-dark / mellow-light)
- **特点**: 圆角设计，视觉效果更现代。
- **适用范围**: **仅限 Wayland 原生应用**。
- **限制**: 在 XWayland 应用（如微信）中，透明圆角背景会被渲染为难看的**黑色方角**。

### 2. Inflex 系列 (inflex-dark / inflex-light)
- **特点**: 直角设计，视觉风格硬朗。
- **适用范围**: **XWayland 兼容模式**。
- **地位**: 作为微信等 XWayland 应用的安全回退方案。
- **注意**: 请勿为了美观而在 Inflex 主题中重新引入透明圆角背景，否则会导致微信输入框出现黑角。

## 微信黑角根因

微信 UOS 使用了 XWayland / fcitx4 兼容路径。该路径下，X11 的 Alpha 通道处理与 Wayland 混成器存在不一致，导致具有透明度的圆角背景在不支持该特性的窗口装饰下显示为纯黑色。
