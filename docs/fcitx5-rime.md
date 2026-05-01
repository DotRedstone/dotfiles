# 输入法配置 (Fcitx5 & Rime)

输入法配置采用了高度原子化的模块设计，确保 Fcitx5 框架、Rime 引擎与 Noctalia 主题之间解耦。

## 模块职责

| 模块 | 职责 |
| :--- | :--- |
| `env.nix` | 定义 IM 环境变量（在 Wayland 下不设置 GTK_IM_MODULE 以使用原生前端） |
| `config/behavior.nix` | Fcitx5 基础行为设置 (CapsLock 处理, 输入状态共享) |
| `config/hotkeys.nix` | Fcitx5 触发键与切换键定义 |
| `rime/schema.nix` | Rime 方案选择与分页设置 |
| `rime/patches/` | Rime 原子化补丁集 (按键绑定、处理器、模式识别) |
| `theme.nix` | 引入 Noctalia 动态生成的主题包 |

## Rime 行为补丁 (Patches)

- **方案**: 雾凇拼音 (`rime_ice`)。
- **分页**: `page_size: 10`。
- **快捷键映射**:
  - `;`: 选择第 2 个候选词。
  - `'`: 选择第 3 个候选词。
  - `[`: 提交首字。
  - `]`: 提交尾字。
  - `Shift`: 提交原始编码 (`commit_code`)。
- **CapsLock 行为**: 在 Fcitx5 中设为 `None`，完全交由 Rime 处理中英文切换。

## Noctalia Fcitx5 主题同步

Noctalia 提供两种主要的输入法主题系列，以应对不同的环境：

1. **Mellow 系列 (Rounded)**: 圆角透明设计，推荐用于原生 Wayland 应用；不建议用于 WeChat/XWayland。
2. **Inflex 系列 (Rectangular)**: 直角设计。**XWayland 应用安全方案**（如微信）。

### 微信输入法黑角问题
WeChat UOS 在 XWayland/fcitx4 兼容模式下无法正确处理透明圆角背景。
- **现象**: 候选框背景会出现黑色方块边缘。
- **对策**: 若当前环境需要兼容 WeChat/XWayland，应使用 **Inflex** 系列直角主题作为全局安全方案；不要把透明圆角重新加回 XWayland-safe 主题。
- **禁忌**: 严禁重新向 Inflex 主题中引入透明圆角背景。

相关链接：
- [Noctalia 视觉系统](./noctalia.md)
- [微信集成说明](./wechat.md)
