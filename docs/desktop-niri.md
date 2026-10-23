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
| `Mod + Shift + S` | 冻结画面后选取区域；详见下文 |

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

## 截图与文字识别

| 按键 | 用法 |
| --- | --- |
| `Mod + Shift + W` | 截取当前聚焦窗口；Niri 将图片复制到剪贴板并保存到其截图目录。 |
| `Mod + Shift + S` | 打开 Niri 冻结画面的区域选择器；按 `Ctrl + C` 仅复制，直接确认则复制并保存。 |
| `Mod + Shift + A` | 选择当前画面的区域并复制到剪贴板，不冻结画面。 |
| `Print` | 截取当前桌面并复制到剪贴板。多屏时包含整个桌面。 |
| `Mod + Shift + P` | 冻结画面并打开 Noctalia 标注编辑器。`B` 为画笔，`C` 为裁剪，`Ctrl + C` 复制，`Ctrl + S` 保存。 |
| `Mod + Shift + O` | 选择区域，用本地 Tesseract 识别简体中文和英文，并将文字复制到剪贴板。取消选择不会改动剪贴板。 |

### 长内容

网页长截图使用 Zen Browser 的页面截图：在网页内按 `Ctrl + Shift + S`，选择
“保存完整页面”，再复制或下载图片。此操作针对网页，不保证页面内独立滚动区域、
动态加载内容或其他应用的长视图完整；保存后检查图片的顶部、中部和底部。
参考 [Zen 快捷键](https://docs.zen-browser.app/user-manual/shortcuts) 与
[Firefox 页面截图说明](https://support.mozilla.org/en-US/kb/take-screenshots-firefox)。

当前没有任意应用通用的滚动长截图快捷键。Niri 和 `grim` 捕获已显示的画面；
文档和 PDF 优先使用应用自身的导出或打印功能，终端内容优先保存文本日志。
无导出功能的视图可分段保存可见画面，并检查各段是否覆盖所需内容。

OCR 的 PNG 临时文件位于运行时目录，命令结束后删除；识别在本机完成。`fel/ocr`
插件保持禁用，当前快捷键直接使用声明式的中英 Tesseract 语言包。

### 工作区
| 按键 | 功能 |
| :--- | :--- |
| `Mod + 1..0` | 切换至工作区 1..10 |
| `Mod + Alt + 1..0` | 将窗口移至工作区 1..10 |

相关链接：
- [Noctalia 视觉系统](./noctalia.md)
- [输入法配置](./fcitx5-rime.md)
