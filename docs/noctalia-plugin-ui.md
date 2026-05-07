# Noctalia 插件 UI 规范

## 总原则

Noctalia 插件 UI 应优先使用官方基础组件：`qs.Commons`、`qs.Widgets`、`Style`、`Color`、`NText`、`NIcon`、`NIconButton`、`NBox`、`NTabBar`、`NTabButton`。本仓库的 `home/dot/noctalia/config/plugins/_shared/` 只补足官方组件体系里缺少的业务级通用组件。

插件 Panel 只做展示和轻量状态组合，复杂业务逻辑放在 helper、provider 或 `Main.qml`。常规插件面板应由 Card、Section、Metric、List、Empty、Warning 组合，不在每个插件里重复手写 `Rectangle` 卡片、进度条、状态胶囊和空状态。

共享组件不得读取插件 settings、不得调用 helper、不得读写 cache，不依赖某个插件的 `mainInstance`。

## 组件使用规范

### PluginCard

统一插件面板里的卡片容器。

```qml
Shared.PluginCard {
    variant: "surfaceVariant"
    outlined: true

    Shared.SectionHeader {
        icon: "chart-bar"
        title: "Today"
    }
}
```

### SectionHeader

统一 section 标题行，支持右侧动作。

```qml
Shared.SectionHeader {
    icon: "history"
    title: "Last 7 Days"
    subtitle: "Local summary"
    actionIcon: "refresh"
    onActionClicked: mainInstance.refresh()
}
```

### MetricCard

统一小统计卡片，用于 prompts、sessions、AFK、当前应用等。

```qml
Shared.MetricCard {
    icon: "message-circle"
    label: "Prompts"
    value: "16"
    subtext: "Today"
}
```

### MetricRow

统一左侧 label、右侧 value、可选 subtext 的列表行。

```qml
Shared.MetricRow {
    label: "GPT 5.5"
    value: "27.2M Tokens"
    subtext: "Cache read included"
}
```

### ProgressBar

统一进度条。`value` 范围为 `0.0-1.0`，默认超过 `0.7` 使用 warning 色，超过 `0.9` 使用 error 色。

```qml
Shared.ProgressBar {
    value: 0.71
    animated: true
}
```

### StatusBadge

统一状态胶囊，用于 source status、tier label、API 状态。

```qml
Shared.StatusBadge {
    text: "Connected"
    icon: "circle-check"
    variant: "success"
}
```

### SegmentedControl

统一分段切换按钮，用于短选项。

```qml
Shared.SegmentedControl {
    model: ["日", "周", "月"]
    currentIndex: 0
    onClicked: index => root.modeIndex = index
}
```

### EmptyState

统一空状态。

```qml
Shared.EmptyState {
    icon: "inbox"
    title: "No data"
    description: "Waiting for local summary."
}
```

### WarningBanner

统一警告和错误提示条。

```qml
Shared.WarningBanner {
    variant: "error"
    title: "Provider unavailable"
    message: "Check local auth status."
}
```

### BarChart

统一简单柱状图，不承担复杂图表逻辑。

```qml
Shared.BarChart {
    model: [
        { label: "Mon", value: 120 },
        { label: "Tue", value: 80 }
    ]
}
```

## 颜色规范

背景使用 `Color.mSurface` 和 `Color.mSurfaceVariant`。主强调使用 `Color.mPrimary`。正文使用 `Color.mOnSurface`，次级文本使用 `Color.mOnSurfaceVariant`。边框使用 `Color.mOutline` 或 `Qt.alpha(Color.mOutline, 0.2)`。错误使用 `Color.mError`。

插件 QML 中禁止新增大面积硬编码 `#xxxxxx` 颜色。允许少量通过 `Qt.alpha(Color.*, value)` 派生透明度。

## 间距和圆角规范

页面外边距使用 `Style.marginL`。卡片内边距使用 `Style.marginL`。section 间距使用 `Style.marginL`。行内间距使用 `Style.marginS` 或 `Style.marginM`。卡片圆角使用 `Style.radiusS` 或 Noctalia 已有常用 radius。小胶囊使用 `height / 2`。不要在单个插件里重新定义一套圆角体系。

## 字体规范

大数字使用 `Style.fontSizeXXXL` 或 `Style.fontSizeXXL`，加粗。section title 使用 `Style.fontSizeL` 和 semi/bold。正文使用 `Style.fontSizeM`。次级文本使用 `Style.fontSizeS` 或 `Style.fontSizeXS`，颜色为 `Color.mOnSurfaceVariant`。插件中不直接写裸 pixel 字号。

## 状态规范

正常状态使用 `primary` 或 `neutral`。警告使用 warning 风格或 error alpha 背景。错误使用 `WarningBanner` 的 `error`。空状态使用 `EmptyState`。加载中应显示泛化 waiting/source 状态，不展示原始响应。

## 隐私规范

UI 不展示 token、API key、session、cookie。`screen-time` 不展示 title、URL、windowTitle、fileName、raw events。`model-usage` 不展示 email、token、raw JSON。错误信息应泛化，不打印原始响应。

## 新插件 Checklist

- 是否使用 `_shared` 组件组织 Card、Section、Metric、List、Empty、Warning。
- 是否避免新增大面积硬编码颜色。
- 是否避免把复杂业务逻辑塞进 `Panel.qml`。
- 是否提供 `EmptyState`。
- 是否提供错误或 warning 状态。
- 是否使用 `Style.*` 和 `Style.uiScaleRatio` 保持缩放。
- 是否 `home-manager build --flake .#dot@warden` 通过。
- 是否没有 cache、secret、token、session、原始 usage 或 ActivityWatch 数据进入 git。

## 迁移顺序建议

已迁移第一批：`screen-time`、`model-usage`。后续建议顺序为 `keybind-cheatsheet`、`privacy-indicator`、`clipper`、`todo`、`screen-toolkit`。其中 `screen-toolkit` 有截图和 overlay 场景，应最后单独整理工具态视觉。
