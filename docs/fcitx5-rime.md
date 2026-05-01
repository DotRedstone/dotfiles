# 输入法配置 (Fcitx5 & Rime)

输入法配置采用了原子化模块设计，确保 Fcitx5 框架、Rime 引擎与 Noctalia 主题之间解耦。

## 模块结构

- **`env.nix`**: 处理 IM 环境变量。
- **`config/`**: 处理 Fcitx5 基础行为。
- **`rime/`**: 核心输入逻辑。
  - **`patches/`**: 包含 `ascii-composer`, `keybindings`, `lua-processors`, `recognizer` 等原子化补丁。

## Rime 行为补丁

- **方案**: 雾凇拼音 (`rime_ice`)。
- **分页**: `page_size: 10`。
- **快捷键**:
  - `;`: 选择第 2 个候选词。
  - `'`: 选择第 3 个候选词。
  - `[`: 提交首字。
  - `]`: 提交尾字。
  - `Shift`: 提交编码 (`commit_code`)。
  - `CapsLock`: 在 Rime 中接管，用于中英文切换。

## 主题适配与兼容性

Noctalia 提供两种主要的输入法主题系列：

- **Mellow**: 圆角透明，视觉效果极佳，仅限 Wayland 原生应用。
- **Inflex (Rectangular)**: 直角不透明，作为 **XWayland 安全回退方案**。

### 微信黑角问题
WeChat UOS 通过 XWayland/fcitx4 兼容路径运行，无法处理透明圆角背景。
- **现象**: 候选框背景出现难看的黑色方角。
- **对策**: 在微信中必须使用 **Inflex** 系列直角主题。
- **原则**: 严禁为了微信而给全局主题添加透明圆角补丁，应保持 Inflex 的直角属性。
 stone
