# Noctalia 视觉系统 (Visual System)

Noctalia 是本系统的核心视觉系统与桌面外壳 (Shell)，基于 Material Design 3 规范构建。

## 核心功能

- **动态调色盘**: 随壁纸自动生成配色方案。
- **User Templates**: Noctalia 的模板系统允许将动态配色同步到非原生应用中。
  - **Starship**: 终端提示符配色。
  - **Zellij**: 终端复用器主题。
  - **NixVim**: 编辑器色彩体系。
  - **Fcitx5**: 输入法皮肤配色。
- **Noctalia Shell**: 提供 Launcher, Notifications, Control Center 等核心 UI 组件。

## 配色原则

- **MD3 Semantic Tokens**: 配置文件应优先使用语义化色彩 Token（如 `primary`, `surface`, `on_surface`）而非具体的十六进制色值。
- **同步逻辑**: 模板文件存放在仓库中，Noctalia 运行时会渲染结果。

## 维护禁令

- **不提交生成文件**: 严禁将 Noctalia 生成的 `.cache` 或渲染后的配置文件提交至 Git。
- **读写权限**: 确保生成目录（如输入法皮肤目录）在 Home Manager 中保持可写，不要将其作为只读的 `symlinkJoin` 挂载。
