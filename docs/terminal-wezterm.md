# 终端 (WezTerm)

WezTerm 是系统的主终端，提供极致的渲染性能与灵活的 Lua 配置。

## 配置方式

- **Home Manager 启用**: 配置位于 `home/dot/wezterm/`。
- **Live Reload**: `config.lua` 使用了 `mkOutOfStoreSymlink` 链接至本地目录，支持配置修改后实时生效。

## 视觉与性能

- **渲染器**: 强制启用 `WebGpu` 后端，设置 `HighPerformance` 优先。
- **刷新率**: 动画 FPS 同步至高刷显示器 (165Hz)。
- **字体**:
  - 主字体: `Maple Mono NF`
  - 中文回退: `Noto Sans CJK SC`
  - 符号: `Symbols Nerd Font Mono`
- **样式**: 无 Tab Bar，无窗口装饰，配色同步自 Noctalia。

## SSH 远程域 (SSH Domains)

已预设以下常用服务器入口：
- **Beacon**: 香港服务器。
- **Conduit**: RN 节点。
- **Hopper**: Oracle 节点。
- **Target**: 腾讯云节点。
- **Repeater**: 阿里云节点。

## 核心快捷键

- `Ctrl + Shift + S`: 调出启动器 (Launcher)
- `Ctrl + Shift + P`: 命令面板
- `Ctrl + Shift + N`: 新建窗口
- `Ctrl + Shift + W`: 关闭当前标签页
