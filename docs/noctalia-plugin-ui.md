# Noctalia 插件 UI 规范草案

## 背景

Noctalia 已经提供了可复用的基础组件和主题入口，例如 `qs.Commons`、`qs.Widgets`、`Style`、`Color`、`NText`、`NIcon`、`NIconButton`、`NTabBar`、`NBox` 等。插件应优先基于这些组件和 MD3 语义 token 组合界面。

本次调研发现，当前插件虽然普遍使用了 `NText`、`NIcon`、`Style`、`Color`，但卡片、进度条、列表行、状态徽标、分段按钮仍大量手写 `Rectangle`。随着插件增多，这会导致圆角、边距、背景透明度、状态色和列表密度不一致。

第一阶段新增插件共享组件目录：

```text
home/dot/noctalia/config/plugins/_shared/
```

这些组件只服务于用户插件层，不修改官方 Noctalia 核心组件。

## 共享组件

### PluginCard

用于插件面板中的普通内容卡片。

规则：

- 默认使用 `Color.mSurfaceVariant` 作为卡片背景。
- 默认圆角使用 `Style.radiusS`。
- 默认内边距使用 `Style.marginL`。
- 需要强调边界时使用 `bordered: true`，边框色使用语义色加透明度，不手写大面积颜色。

### SectionHeader

用于卡片内 section 标题。

规则：

- 标题使用 `NText`、`Style.fontSizeL`、`Style.fontWeightBold`。
- 图标使用 `NIcon` 和 `Color.mPrimary`。
- 右侧元信息使用 `Color.mOnSurfaceVariant`。
- 不在每个插件里重复手写标题行。

### MetricRow

用于应用列表、指标列表、简短数据行。

规则：

- 行背景默认使用 `Color.mSurface` 的低透明叠层。
- 图标或首字母标识使用同一尺寸和圆角。
- 主标签、辅助文本、数值位置固定。
- 有占比时使用内置 `ProgressBar`，不要每个插件重复写进度条。

### ProgressBar

用于水平占比条。

规则：

- 轨道默认使用 `Color.mOutline` 的低透明叠层。
- 填充默认使用 `Color.mPrimary`。
- 高度默认跟随 `Style.uiScaleRatio`。
- 不直接硬编码十六进制颜色。

### StatusBadge

用于连接状态、类别标签、轻量状态提示。

规则：

- 默认使用胶囊式低透明背景。
- 成功/普通状态优先用 `Color.mPrimary`。
- 错误状态用 `Color.mError`。
- 不把长错误详情或原始 JSON 放进 badge。

### SegmentedControl

用于插件内部的短组选项，例如 `日 / 周 / 月`。

规则：

- 容器使用 `Color.mSurfaceVariant`。
- 选中项使用 `Color.mPrimary` 和 `Color.mOnPrimary`。
- 未选中项使用 `Color.mOnSurfaceVariant`。
- 选项数量应保持较少，避免替代完整 tab bar。

### EmptyState

用于空列表、无数据、安全错误的泛化提示。

规则：

- 使用 `NIcon` 和 `NText`。
- 只显示泛化错误，不展示 token、session、URL、窗口标题、原始响应或完整事件。
- 描述文本保持简短，可引导用户检查服务状态。

## 间距与圆角

推荐规则：

- 面板外边距使用 `Style.marginL`。
- 卡片内边距使用 `Style.marginL`。
- section 间距使用 `Style.marginL`。
- 卡片内控件间距使用 `Style.marginM`。
- 紧凑文本间距使用 `Style.marginXS` 或 `Style.marginXXS`。
- 普通卡片和行项目圆角使用 `Style.radiusS`。
- 浮层、工具面板、截图工具等特殊界面可使用 `Style.radiusM` 或 `Style.radiusL`，但应在插件内说明原因。

## 当前调研结论

### screen-time

- 已使用 `NText`、`NIconButton`、`Style`、`Color`。
- 原先手写了 tab segment、主卡片、图表卡片、应用卡片、应用行、进度条、状态 chip。
- 本次已将 `Panel.qml` 迁移到 `_shared` 的 `PluginCard`、`SectionHeader`、`MetricRow`、`ProgressBar`、`StatusBadge`、`SegmentedControl`、`EmptyState`。
- 图表柱形仍保留在插件内，因为它属于 screen-time 的业务视图。

### model-usage

- 使用了 `NTabBar`、`NTabButton`、`NText`、`NIcon`、`NIconButton`、`Style`、`Color`。
- 仍手写 provider header、tier badge、错误卡片、rate limit card、quota row、progress bar。
- 本次只记录，不迁移。

### clipper

- 使用了 `NText`、`NIconButton`、`Style`、`Color`。
- 存在大量自定义 card、filter button、badge、fallback hex color。
- 剪贴板内容展示有较强业务特性，建议在 model-usage 之后迁移通用筛选和 badge 部分。

### keybind-cheatsheet

- Settings 中已有 `NBox` 等基础组件使用。
- Panel 中仍手写 key cap、分类卡片、搜索结果行。
- 结构较简单，适合作为第二批迁移对象。

### screen-toolkit

- 使用了 `NIconButtonHot`、`NText`、`NIcon`、`Style`、`Color`。
- 截图、录屏、钉图等 overlay 场景存在硬编码透明遮罩、红色录制边框、白色提示文字。
- 这些属于工具态视觉，不建议第一阶段套普通插件卡片组件；应最后单独梳理 overlay token。

## 迁移顺序建议

1. `screen-time`：作为共享组件试点，已完成第一阶段迁移。
2. `model-usage`：卡片、quota row、progress bar 与 shared 组件高度匹配。
3. `keybind-cheatsheet`：key row 和 section card 可低风险统一。
4. `clipper`：先迁移筛选 badge 和空状态，再评估内容卡片。
5. `screen-toolkit`：最后单独处理 overlay/工具态视觉，不直接套普通面板规范。

## 隐私与安全

插件 UI 组件只负责展示结构，不应读取或保存运行时敏感数据。具体插件仍需遵守各自数据边界：

- 不展示 token、session、cache 路径或原始日志。
- 不展示 ActivityWatch 原始事件、窗口标题、URL、文件名或完整时间线。
- 不把运行时 cache、summary JSON、数据库加入仓库或 persistence。
