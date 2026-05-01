# Niri 桌面配置 (Desktop Niri)

Niri 是本系统的主合成器 (Compositor)，提供可滚动的平铺窗口管理体验。

## 启动链

Niri 启动时会自动执行以下关键项：
1. `xwayland-satellite`: 提供 X11 应用兼容性。
2. `dbus-update-activation-environment`: 同步 D-Bus 环境变量。
3. `noctalia-shell`: 启动桌面外壳。
4. `fcitx5 -d --replace`: 启动输入法框架。

## 布局与装饰 (Layout)

- **间隙 (Gaps)**: 默认 14。
- **圆角**: 窗口圆角半径 20。
- **透明度**: 全局默认不透明度 0.80。
- **背景特效**: 开启毛玻璃模糊 (Blur) 与 Xray 效果。
- **原则**: 禁止为了单个应用的不美观而修改全局不透明度或窗口规则。

## 核心快捷键 (Mod = Super/Win 键)

### 应用启动
- `Mod + Return`: WezTerm (终端)
- `Mod + W`: Firefox (浏览器)
- `Mod + E`: Nautilus (文件管理器)
- `Mod + R`: Noctalia Launcher (搜索/启动器)

### 窗口管理
- `Mod + Q`: 关闭当前窗口
- `Mod + F`: 切换当前列最大化
- `Mod + Shift + F`: 切换全屏
- `Mod + Minus / Equal`: 调整窗口宽度

### 系统功能
- `Mod + N`: 通知面板 (Noctalia)
- `Mod + B`: 剪贴板历史 (Clipper)
- `Mod + I`: 控制中心 (Control Center)
- `Mod + P`: 电源菜单
- `Print`: 全屏截图并存入剪贴板
- `Mod + Shift + S`: 区域截图并存入剪贴板

### 工作区与导航
- `Mod + 1..0`: 切换工作区
- `Mod + Alt + 1..0`: 将窗口移至工作区
- `Mod + L / J / K`: 向右、向下、向上切换焦点
