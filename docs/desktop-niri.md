# Niri 桌面配置 (Desktop Niri)

Niri 是本系统的核心窗口管理器，提供可滚动的平铺窗口管理体验。

## 启动链 (Startup Chain)

Niri 启动时会通过 `spawn-at-startup` 执行以下序列：
1. `xwayland-satellite`: 提供 X11 应用支持。
2. `dbus-update-activation-environment --systemd --all`: 同步环境变量至 D-Bus/Systemd。
3. `noctalia-shell`: 启动桌面 UI 外壳。
4. `fcitx5 -d --replace`: 启动输入法框架（带 1 秒延迟以确保桌面就绪）。

## 全局视觉规范

- **圆角**: 窗口圆角半径 `20`。
- **透明度**: 全局默认不透明度 `0.80`。
- **特效**: 开启 `Blur` (2 passes), `Xray`, 及轻微 `Noise` 效果。
- **原则**: 禁止为了解决单个应用（如微信）的显示问题而降低全局视觉质量。

## 核心快捷键 (Mod = Super/Win 键)

### 应用启动与系统
| 按键 | 功能 |
| :--- | :--- |
| `Mod + Return` | 启动 WezTerm (终端) |
| `Mod + W` | 启动 Firefox (浏览器) |
| `Mod + E` | 启动 Nautilus (文件管理器) |
| `Mod + R` | 切换 Noctalia Launcher (启动器) |
| `Mod + N` | 切换 Noctalia 通知面板 |
| `Mod + B` | 切换 Noctalia 剪贴板 (Clipper) |
| `Mod + I` | 切换 Noctalia 控制中心 |
| `Mod + P` | 切换电源菜单 |
| `Print` | 全屏截图并存入剪贴板 |
| `Mod + Shift + S` | 区域截图并存入剪贴板 |

### 窗口管理
| 按键 | 功能 |
| :--- | :--- |
| `Mod + Q` | 关闭当前窗口 |
| `Mod + F` | 切换列最大化 |
| `Mod + Shift + F` | 切换全屏 |
| `Mod + Shift + C` | 窗口居中 |
| `Mod + L / J / K` | 向右/下/上切换焦点 |
| `Mod + Shift + L/J/K` | 向右/下/上移动窗口 |
| `Mod + - / =` | 缩小/放大窗口宽度 |

### 工作区
| 按键 | 功能 |
| :--- | :--- |
| `Mod + 1..0` | 切换至工作区 1..10 |
| `Mod + Alt + 1..0` | 将窗口移至工作区 1..10 |

相关链接：
- [Noctalia 视觉系统](./noctalia.md)
- [输入法配置](./fcitx5-rime.md)
