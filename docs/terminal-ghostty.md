# 终端 (Ghostty)

Ghostty 是系统的默认终端。选择它替代 WezTerm 的主要原因是滚动行为：WezTerm 只按整行滚动，且滚轮步长在近期版本已不是配置项；Ghostty 可通过 `mouse-scroll-multiplier` 让触控板按像素增量滚动。

## 核心特性

- **渲染后端**: 原生 Wayland + GPU 渲染，无额外开关。
- **字体栈**（与旧 WezTerm 配置一致）:
  1. `Maple Mono NF`
  2. `Noto Sans CJK SC` (中文回退)
  3. `Symbols Nerd Font Mono`
- **光标**: `bar` + 闪烁，`adjust-cursor-thickness` 用于调整竖线粗细。该值是在字体派生粗细上增减的像素数，不是绝对宽度。
- **窗口外观**: 无装饰、无标签栏、内边距 `10x8` 像素，对应旧配置的 `window_decorations = "NONE"`、`enable_tab_bar = false` 与 `1cell / 0.5cell` 内边距。

## 滚动

| 配置 | 含义 |
| :--- | :--- |
| `mouse-scroll-multiplier = precision:1` | 触控板等像素精度设备严格跟随像素增量，可停在行中间 |
| `discrete:3` | 滚轮每格 3 行，觉得快可调小 |
| `scrollback-limit-lines = unlimited` | 滚动历史不受行数限制（受 50MB 字节上限约束，自动压缩） |
| `scrollbar = system` | 显示滚动条，便于判断当前所处缓冲位置 |

## 核心快捷键

均为 Ghostty 默认键位，无需额外配置：

| 按键组合 | 功能 |
| :--- | :--- |
| `Ctrl + Shift + P` | 命令面板 |
| `Ctrl + Shift + N` | 新窗口 |
| `Ctrl + Shift + T` | 新建标签页 |
| `Ctrl + Shift + W` | 关闭标签页 |
| `Ctrl + Shift + C` | 复制（`mixed` 模式：程序启用鼠标上报时交由程序处理） |

## 与旧 WezTerm 配置的差异

- **无内置多路复用**：WezTerm 的 `ssh_domains` 与 mux server 在 Ghostty 中没有对应物。远程节点仍通过 `~/.ssh/config` 中的别名直接 `ssh <别名>` 连接，会话保持由 `zellij` 负责。
- **配色来源不变**：`ghostty_noctalia` matugen 模板由 `desktop-shells/dms.nix` 生成，与 DMS 主题使用同一组颜色令牌，随壁纸动态同步。

## 维护原则

- **Live Reload**: `~/.config/ghostty/config` 通过 `mkOutOfStoreSymlink` 指向本仓库的 `home/dot/ghostty/config`，修改后新开窗口即生效，**无需**运行 `hms`。
- **配色同步**: 主题文件 `~/.config/ghostty/themes/Noctalia` 由 DMS 的 matugen 模板生成，不要手工编辑；颜色令牌在 `desktop-shells/dms.nix` 中维护。
- **配置校验**: 改动后可用 `ghostty +validate-config` 验证，该命令会拒绝未知字段。

相关链接：
- [Noctalia 视觉系统](./noctalia.md)
- [密钥管理](./secrets-sops.md)
