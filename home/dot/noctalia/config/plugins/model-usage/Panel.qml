import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import "../_shared" as Shared

Item {
    id: root

    property var pluginApi: null
    property var mainInstance: pluginApi?.mainInstance
    readonly property color usageWarnColor: Qt.alpha(Color.mError, 0.72)

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 400 * Style.uiScaleRatio
    property real contentPreferredHeight: 560 * Style.uiScaleRatio

    anchors.fill: parent

    onVisibleChanged: {
        if (visible)
            mainInstance?.refreshIfStale();
    }

    property int selectedTabIndex: 0
    property var selectedProvider: {
        const ep = mainInstance?.enabledProviders ?? [];
        if (ep.length === 0)
            return null;
        return ep[Math.min(selectedTabIndex, ep.length - 1)];
    }

    function usageRatio(usagePercent) {
        const u = usagePercent ?? -1;
        if (u < 0)
            return -1;
        const mode = mainInstance?.usageDisplayMode ?? "usage";
        const val = mode === "remaining" ? (1.0 - u) : u;
        return Math.min(1.0, Math.max(0, val));
    }

    function usagePercentText(usagePercent) {
        const ratio = usageRatio(usagePercent);
        if (ratio < 0)
            return "\u2014";
        return Math.round(ratio * 100) + "%";
    }

    function usageTone(usagePercent) {
        const u = usagePercent ?? -1;
        if (u < 0)
            return Color.mOnSurfaceVariant;
        if (u >= 0.9)
            return Color.mError;
        if (u >= 0.7)
            return root.usageWarnColor;
        return Color.mOnSurface;
    }

    function usageAccent(usagePercent) {
        const u = usagePercent ?? -1;
        if (u >= 0.9)
            return Color.mError;
        if (u >= 0.7)
            return root.usageWarnColor;
        return Color.mPrimary;
    }

    function quotaResetText(modelData) {
        if ((modelData?.resetAt ?? "") === "")
            return "";
        if ((root.selectedProvider?.providerId ?? "") === "codex") {
            const resetText = root.selectedProvider?.formatQuotaResetText(modelData) ?? "";
            if (resetText !== "")
                return resetText;
        }
        return (pluginApi?.tr("panel.resets_in") ?? "Resets in {time}").replace("{time}", (root.selectedProvider?.formatResetTime(modelData.resetAt ?? "") ?? ""));
    }

    function maxRecentMessageCount() {
        const days = root.selectedProvider?.recentDays ?? [];
        let maxCount = 1;
        for (let i = 0; i < days.length; i++) {
            if ((days[i]?.messageCount ?? 0) > maxCount)
                maxCount = days[i].messageCount;
        }
        return maxCount;
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: 0

            Shared.SegmentedControl {
                Layout.fillWidth: true
                visible: (mainInstance?.enabledProviders ?? []).length > 1
                options: {
                    const providers = mainInstance?.enabledProviders ?? [];
                    const tabs = [];
                    for (let i = 0; i < providers.length; i++) {
                        tabs.push({
                            key: String(i),
                            label: providers[i]?.providerName ?? ("Provider " + String(i + 1))
                        });
                    }
                    return tabs;
                }
                currentKey: String(root.selectedTabIndex)
                onSelected: key => {
                    const idx = parseInt(key, 10);
                    if (!isNaN(idx))
                        root.selectedTabIndex = idx;
                }
            }

            Item {
                height: (mainInstance?.enabledProviders ?? []).length > 1 ? Style.marginM : 0
                Layout.fillWidth: true
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: contentLayout.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: contentLayout
                    width: parent.width
                    spacing: Style.marginL

                    Shared.EmptyState {
                        visible: !root.selectedProvider
                        icon: "plug-connected-x"
                        title: pluginApi?.tr("panel.no_providers") ?? "No providers enabled."
                        description: pluginApi?.tr("panel.no_providers") ?? "Enable providers in Settings."
                        Layout.topMargin: Style.marginXL
                    }

                    Shared.EmptyState {
                        visible: root.selectedProvider && !root.selectedProvider.ready
                        icon: "hourglass"
                        title: root.selectedProvider ? (root.selectedProvider.providerName + (pluginApi?.tr("panel.waiting_data") ?? " — waiting for data...")) : ""
                        Layout.topMargin: Style.marginXL
                    }

                    Shared.PluginCard {
                        visible: !!root.selectedProvider

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginM

                            NIcon {
                                icon: root.selectedProvider?.providerIcon ?? "ai"
                                pointSize: Style.fontSizeXXXL
                                color: Color.mPrimary
                            }

                            NText {
                                text: (root.selectedProvider?.providerName ?? "") + (pluginApi?.tr("panel.usage_suffix") ?? " Usage")
                                pointSize: Style.fontSizeXL
                                font.weight: Style.fontWeightBold
                                color: Color.mOnSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Shared.StatusBadge {
                                visible: (root.selectedProvider?.tierLabel ?? "") !== ""
                                label: root.selectedProvider?.tierLabel ?? ""
                                accentColor: Color.mPrimary
                                textColor: Color.mPrimary
                            }
                        }
                    }

                    Shared.WarningBanner {
                        visible: !!root.selectedProvider && (root.selectedProvider?.usageStatusText ?? "") !== ""
                        variant: "error"
                        title: root.selectedProvider?.usageStatusText ?? ""
                        message: root.selectedProvider?.authHelpText ?? ""
                    }

                    Shared.PluginCard {
                        visible: ((root.selectedProvider?.quotas ?? []).length > 0)
                            || (root.selectedProvider?.rateLimitPercent ?? -1) >= 0
                            || (root.selectedProvider?.secondaryRateLimitPercent ?? -1) >= 0

                        Shared.SectionHeader {
                            title: {
                                const mode = mainInstance?.usageDisplayMode ?? "usage";
                                if (mode === "remaining")
                                    return pluginApi?.tr("general.usage_display_mode_remaining") ?? "Remaining";
                                return pluginApi?.tr("panel.rate_limit_title") ?? "Rate Limit Usage";
                            }
                            icon: "gauge"
                        }

                        Repeater {
                            id: quotaRepeater
                            model: (root.selectedProvider?.quotas ?? []).length > 0 ? root.selectedProvider.quotas : []

                            Shared.MetricRow {
                                required property var modelData
                                Layout.fillWidth: true
                                showBackground: true
                                label: modelData.label ?? ""
                                value: root.usagePercentText(modelData.percent)
                                subtitle: root.quotaResetText(modelData)
                                progress: root.usageRatio(modelData.percent)
                                accentColor: root.usageAccent(modelData.percent)
                            }
                        }

                        ColumnLayout {
                            visible: (root.selectedProvider?.quotas ?? []).length === 0
                            Layout.fillWidth: true
                            spacing: Style.marginM

                            ColumnLayout {
                                visible: (root.selectedProvider?.rateLimitPercent ?? -1) >= 0
                                Layout.fillWidth: true
                                spacing: 0

                                Shared.MetricRow {
                                    showBackground: true
                                    label: root.selectedProvider?.rateLimitLabel ?? ""
                                    value: root.usagePercentText(root.selectedProvider?.rateLimitPercent ?? -1)
                                    subtitle: (root.selectedProvider?.rateLimitResetAt ?? "") !== "" ? (pluginApi?.tr("panel.resets_in") ?? "Resets in {time}").replace("{time}", (root.selectedProvider?.formatResetTime(root.selectedProvider?.rateLimitResetAt ?? "") ?? "")) : ""
                                    progress: root.usageRatio(root.selectedProvider?.rateLimitPercent ?? -1)
                                    accentColor: root.usageAccent(root.selectedProvider?.rateLimitPercent ?? -1)
                                    Layout.fillWidth: true
                                }
                            }

                            ColumnLayout {
                                visible: (root.selectedProvider?.secondaryRateLimitPercent ?? -1) >= 0
                                Layout.fillWidth: true
                                spacing: 0

                                Shared.MetricRow {
                                    showBackground: true
                                    label: root.selectedProvider?.secondaryRateLimitLabel ?? ""
                                    value: root.usagePercentText(root.selectedProvider?.secondaryRateLimitPercent ?? -1)
                                    subtitle: (root.selectedProvider?.secondaryRateLimitResetAt ?? "") !== "" ? (pluginApi?.tr("panel.resets_in") ?? "Resets in {time}").replace("{time}", (root.selectedProvider?.formatResetTime(root.selectedProvider?.secondaryRateLimitResetAt ?? "") ?? "")) : ""
                                    progress: root.usageRatio(root.selectedProvider?.secondaryRateLimitPercent ?? -1)
                                    accentColor: root.usageAccent(root.selectedProvider?.secondaryRateLimitPercent ?? -1)
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Shared.PluginCard {
                        visible: (root.selectedProvider?.ready ?? false) && (root.selectedProvider?.hasLocalStats ?? false)

                        Shared.SectionHeader {
                            title: pluginApi?.tr("panel.today_title") ?? "Today"
                            icon: "calendar-stats"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginM

                            Shared.MetricCard {
                                Layout.fillWidth: true
                                icon: "message-circle"
                                label: pluginApi?.tr("panel.prompts") ?? "prompts"
                                value: String(root.selectedProvider?.todayPrompts ?? 0)
                            }

                            Shared.MetricCard {
                                Layout.fillWidth: true
                                icon: "clock-hour-4"
                                label: pluginApi?.tr("panel.sessions") ?? "sessions"
                                value: String(root.selectedProvider?.todaySessions ?? 0)
                            }
                        }

                        Repeater {
                            model: {
                                const toks = root.selectedProvider?.todayTokensByModel ?? {};
                                const result = [];
                                for (const k in toks)
                                    result.push({
                                        modelId: k,
                                        count: toks[k]
                                    });
                                return result;
                            }

                            Shared.MetricRow {
                                required property var modelData
                                Layout.fillWidth: true
                                showBackground: false
                                label: mainInstance?.friendlyModelName(modelData.modelId) ?? modelData.modelId
                                value: (mainInstance?.formatTokenCount(modelData.count) ?? "0") + " " + (pluginApi?.tr("panel.tokens") ?? "tokens")
                            }
                        }
                    }

                    Shared.PluginCard {
                        visible: (root.selectedProvider?.recentDays ?? []).length > 0

                        Shared.SectionHeader {
                            title: pluginApi?.tr("panel.last_7_days") ?? "Last 7 Days"
                            icon: "chart-histogram"
                        }

                        Repeater {
                            model: root.selectedProvider?.recentDays ?? []

                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Style.marginXS

                                Shared.MetricRow {
                                    Layout.fillWidth: true
                                    showBackground: false
                                    label: {
                                        const d = modelData.date;
                                        if (!d)
                                            return "";
                                        const dt = new Date(d + "T00:00:00");
                                        const days = [
                                            pluginApi?.tr("providers.common.sun") ?? "Sun",
                                            pluginApi?.tr("providers.common.mon") ?? "Mon",
                                            pluginApi?.tr("providers.common.tue") ?? "Tue",
                                            pluginApi?.tr("providers.common.wed") ?? "Wed",
                                            pluginApi?.tr("providers.common.thu") ?? "Thu",
                                            pluginApi?.tr("providers.common.fri") ?? "Fri",
                                            pluginApi?.tr("providers.common.sat") ?? "Sat"
                                        ];
                                        return days[dt.getDay()] + " " + String(dt.getMonth() + 1).padStart(2, "0") + "/" + String(dt.getDate()).padStart(2, "0");
                                    }
                                    value: mainInstance?.formatTokenCount(modelData?.messageCount ?? 0) ?? "0"
                                }

                                Shared.ProgressBar {
                                    semanticThresholds: false
                                    barColor: Color.mPrimary
                                    value: {
                                        const maxCount = root.maxRecentMessageCount();
                                        const count = modelData?.messageCount ?? 0;
                                        return maxCount > 0 ? (count / maxCount) : 0;
                                    }
                                }
                            }
                        }
                    }

                    Shared.PluginCard {
                        visible: {
                            const usage = root.selectedProvider?.modelUsage ?? {};
                            return Object.keys(usage).length > 0;
                        }

                        Shared.SectionHeader {
                            title: pluginApi?.tr("panel.all_time") ?? "All-Time"
                            icon: "history"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginM

                            Shared.MetricCard {
                                Layout.fillWidth: true
                                icon: "message-2"
                                label: pluginApi?.tr("panel.messages") ?? "messages"
                                value: mainInstance?.formatTokenCount(root.selectedProvider?.totalPrompts ?? 0) ?? "0"
                            }

                            Shared.MetricCard {
                                Layout.fillWidth: true
                                icon: "clock-hour-4"
                                label: pluginApi?.tr("panel.sessions") ?? "sessions"
                                value: String(root.selectedProvider?.totalSessions ?? 0)
                            }
                        }

                        Repeater {
                            model: {
                                const usage = root.selectedProvider?.modelUsage ?? {};
                                const result = [];
                                for (const k in usage)
                                    result.push({
                                        modelId: k,
                                        data: usage[k]
                                    });
                                return result;
                            }

                            Shared.PluginCard {
                                required property var modelData
                                cardColor: Qt.alpha(Color.mSurface, 0.58)
                                padding: Style.marginM

                                NText {
                                    text: mainInstance?.friendlyModelName(modelData.modelId) ?? modelData.modelId
                                    pointSize: Style.fontSizeM
                                    font.weight: Style.fontWeightSemiBold
                                    color: Color.mOnSurface
                                    Layout.fillWidth: true
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: Style.marginL
                                    rowSpacing: Style.marginXXS

                                    NText {
                                        text: pluginApi?.tr("panel.input") ?? "Input"
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                    NText {
                                        text: mainInstance?.formatTokenCount(modelData.data?.inputTokens ?? 0) ?? "0"
                                        pointSize: Style.fontSizeXS
                                        font.weight: Style.fontWeightSemiBold
                                        color: Color.mOnSurface
                                    }

                                    NText {
                                        text: pluginApi?.tr("panel.output") ?? "Output"
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                    NText {
                                        text: mainInstance?.formatTokenCount(modelData.data?.outputTokens ?? 0) ?? "0"
                                        pointSize: Style.fontSizeXS
                                        font.weight: Style.fontWeightSemiBold
                                        color: Color.mOnSurface
                                    }

                                    NText {
                                        text: pluginApi?.tr("panel.cache_read") ?? "Cache Read"
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                    NText {
                                        text: mainInstance?.formatTokenCount(modelData.data?.cacheReadInputTokens ?? 0) ?? "0"
                                        pointSize: Style.fontSizeXS
                                        font.weight: Style.fontWeightSemiBold
                                        color: Color.mOnSurface
                                    }

                                    NText {
                                        text: pluginApi?.tr("panel.cache_write") ?? "Cache Write"
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                    NText {
                                        text: mainInstance?.formatTokenCount(modelData.data?.cacheCreationInputTokens ?? 0) ?? "0"
                                        pointSize: Style.fontSizeXS
                                        font.weight: Style.fontWeightSemiBold
                                        color: Color.mOnSurface
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
