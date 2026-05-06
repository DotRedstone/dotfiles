import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property var mainInstance: pluginApi?.mainInstance
    readonly property color sectionBackgroundColor: Color.mSurfaceVariant
    readonly property color usageWarnColor: Qt.alpha(Color.mError, 0.72)

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 400 * Style.uiScaleRatio
    property real contentPreferredHeight: 560 * Style.uiScaleRatio

    anchors.fill: parent

    // [Panel-open refresh]
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

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: 0

            NTabBar {
                id: tabBar
                Layout.fillWidth: true
                visible: (mainInstance?.enabledProviders ?? []).length > 1

                Repeater {
                    model: mainInstance?.enabledProviders ?? []

                    NTabButton {
                        required property var modelData
                        required property int index
                        readonly property int tabCount: (mainInstance?.enabledProviders ?? []).length
                        text: modelData.providerName
                        width: tabCount > 0 ? Math.floor(tabBar.width / tabCount) : implicitWidth
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        checked: index === root.selectedTabIndex
                        onClicked: root.selectedTabIndex = index
                    }
                }
            }

            Item {
                height: Style.marginM
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

                    NText {
                        visible: !root.selectedProvider
                        text: pluginApi?.tr("panel.no_providers") ?? "No providers enabled. Enable providers in Settings."
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: Style.marginXL
                    }

                    NText {
                        visible: root.selectedProvider && !root.selectedProvider.ready
                        text: root.selectedProvider ? (root.selectedProvider.providerName + (pluginApi?.tr("panel.waiting_data") ?? " — waiting for data...")) : ""
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: Style.marginXL
                    }

                    RowLayout {
                        visible: !!root.selectedProvider
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
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: (root.selectedProvider?.tierLabel ?? "") !== ""
                            color: Qt.alpha(Color.mPrimary, 0.15)
                            radius: Style.radiusXS
                            implicitWidth: tierText.implicitWidth + Style.marginL
                            implicitHeight: tierText.implicitHeight + Style.marginS

                            NText {
                                id: tierText
                                anchors.centerIn: parent
                                text: root.selectedProvider?.tierLabel ?? ""
                                pointSize: Style.fontSizeS
                                font.weight: Style.fontWeightSemiBold
                                color: Color.mPrimary
                            }
                        }
                    }

                    Rectangle {
                        visible: !!root.selectedProvider
                        Layout.fillWidth: true
                        height: 1
                        color: Color.mOutline
                    }

                    Rectangle {
                        visible: !!root.selectedProvider && (root.selectedProvider?.usageStatusText ?? "") !== ""
                        Layout.fillWidth: true
                        color: Qt.alpha(Color.mError, 0.12)
                        radius: Style.radiusS
                        implicitHeight: authStatusColumn.implicitHeight + Style.marginXL

                        ColumnLayout {
                            id: authStatusColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: Style.marginL
                            }
                            spacing: Style.marginXS

                            NText {
                                text: root.selectedProvider?.usageStatusText ?? ""
                                pointSize: Style.fontSizeM
                                font.weight: Style.fontWeightSemiBold
                                color: Color.mError
                            }

                            NText {
                                text: root.selectedProvider?.authHelpText ?? ""
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurfaceVariant
                            }
                        }
                    }

                    Rectangle {
                        visible: ((root.selectedProvider?.quotas ?? []).length > 0)
                            || (root.selectedProvider?.rateLimitPercent ?? -1) >= 0
                            || (root.selectedProvider?.secondaryRateLimitPercent ?? -1) >= 0
                        Layout.fillWidth: true
                        color: root.sectionBackgroundColor
                        radius: Style.radiusS
                        implicitHeight: rateLimitColumn.implicitHeight + Style.marginXL

                        ColumnLayout {
                            id: rateLimitColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: Style.marginL
                            }
                            spacing: Style.marginM

                            NText {
                                text: {
                                    const mode = mainInstance?.usageDisplayMode ?? "usage";
                                    if (mode === "remaining")
                                        return pluginApi?.tr("general.usage_display_mode_remaining") ?? "Remaining";
                                    return pluginApi?.tr("panel.rate_limit_title") ?? "Rate Limit Usage";
                                }
                                pointSize: Style.fontSizeL
                                font.weight: Style.fontWeightSemiBold
                                color: Color.mPrimary
                            }

                            Repeater {
                                id: quotaRepeater
                                model: (root.selectedProvider?.quotas ?? []).length > 0 ? root.selectedProvider.quotas : null

                                ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Style.marginXS

                                    RowLayout {
                                        Layout.fillWidth: true
                                        NText {
                                            text: modelData.label ?? ""
                                            pointSize: Style.fontSizeS
                                            color: Color.mOnSurfaceVariant
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        NText {
                                            text: {
                                                const u = modelData.percent ?? -1;
                                                if (u < 0)
                                                    return "\u2014";
                                                const mode = mainInstance?.usageDisplayMode ?? "usage";
                                                const val = mode === "remaining" ? (1.0 - u) : u;
                                                return Math.round(val * 100) + "%";
                                            }
                                            pointSize: Style.fontSizeS
                                            font.weight: Style.fontWeightBold
                                            color: {
                                                const u = modelData.percent ?? -1;
                                                if (u < 0) return Color.mOnSurfaceVariant;
                                                if (u >= 0.9) return Color.mError;
                                                if (u >= 0.7) return root.usageWarnColor;
                                                return Color.mOnSurface;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 8
                                        color: Qt.alpha(Color.mOutline, 0.2)
                                        radius: Style.radiusXXS

                                        Rectangle {
                                            anchors {
                                                left: parent.left
                                                top: parent.top
                                                bottom: parent.bottom
                                            }
                                            radius: Style.radiusXXS
                                            color: {
                                                const u = modelData.percent ?? -1;
                                                if (u < 0) return Color.mOutline;
                                                if (u >= 0.9) return Color.mError;
                                                if (u >= 0.7) return root.usageWarnColor;
                                                return Color.mPrimary;
                                            }
                                            width: {
                                                const u = modelData.percent ?? -1;
                                                if (u < 0)
                                                    return 0;
                                                const mode = mainInstance?.usageDisplayMode ?? "usage";
                                                const val = mode === "remaining" ? (1.0 - u) : u;
                                                return parent.width * Math.min(1.0, Math.max(0, val));
                                            }

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: Style.animationNormal
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }

                                    NText {
                                        visible: (modelData.resetAt ?? "") !== ""
                                        text: {
                                            if ((root.selectedProvider?.providerId ?? "") === "codex") {
                                                const resetText = root.selectedProvider?.formatQuotaResetText(modelData) ?? "";
                                                if (resetText !== "")
                                                    return resetText;
                                            }
                                            return (pluginApi?.tr("panel.resets_in") ?? "Resets in {time}").replace("{time}", (root.selectedProvider?.formatResetTime(modelData.resetAt ?? "") ?? ""));
                                        }
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                }
                            }

                            ColumnLayout {
                                visible: (root.selectedProvider?.quotas ?? []).length === 0
                                Layout.fillWidth: true
                                spacing: Style.marginM

                                ColumnLayout {
                                    visible: (root.selectedProvider?.rateLimitPercent ?? -1) >= 0
                                    Layout.fillWidth: true
                                    spacing: Style.marginXS

                                    RowLayout {
                                        Layout.fillWidth: true
                                        NText {
                                            text: root.selectedProvider?.rateLimitLabel ?? ""
                                            pointSize: Style.fontSizeS
                                            color: Color.mOnSurfaceVariant
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        NText {
                                            text: {
                                                const u = root.selectedProvider?.rateLimitPercent ?? -1;
                                                if (u < 0)
                                                    return "\u2014";
                                                const mode = mainInstance?.usageDisplayMode ?? "usage";
                                                const val = mode === "remaining" ? (1.0 - u) : u;
                                                return Math.round(val * 100) + "%";
                                            }
                                            pointSize: Style.fontSizeS
                                            font.weight: Style.fontWeightBold
                                            color: {
                                                const u = root.selectedProvider?.rateLimitPercent ?? 0;
                                                const mode = mainInstance?.usageDisplayMode ?? "usage";
                                                if (mode === "remaining") {
                                                    if (u >= 0.9) return Color.mError;
                                                    if (u >= 0.7) return root.usageWarnColor;
                                                    return Color.mOnSurface;
                                                }
                                                if (u >= 0.9) return Color.mError;
                                                if (u >= 0.7) return root.usageWarnColor;
                                                return Color.mOnSurface;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 8
                                        color: Qt.alpha(Color.mOutline, 0.2)
                                        radius: Style.radiusXXS

                                        Rectangle {
                                            anchors {
                                                left: parent.left
                                                top: parent.top
                                                bottom: parent.bottom
                                            }
                                            radius: Style.radiusXXS
                                            color: {
                                                const u = root.selectedProvider?.rateLimitPercent ?? 0;
                                                if (u >= 0.9)
                                                    return Color.mError;
                                                if (u >= 0.7)
                                                    return root.usageWarnColor;
                                                return Color.mPrimary;
                                            }
                                            width: {
                                                const u = root.selectedProvider?.rateLimitPercent ?? 0;
                                                const mode = mainInstance?.usageDisplayMode ?? "usage";
                                                const val = mode === "remaining" ? (1.0 - u) : u;
                                                return parent.width * Math.min(1.0, Math.max(0, val));
                                            }

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: Style.animationNormal
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }

                                    NText {
                                        visible: (root.selectedProvider?.rateLimitResetAt ?? "") !== ""
                                        text: (pluginApi?.tr("panel.resets_in") ?? "Resets in {time}").replace("{time}", (root.selectedProvider?.formatResetTime(root.selectedProvider?.rateLimitResetAt ?? "") ?? ""))
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                }

                                ColumnLayout {
                                    visible: (root.selectedProvider?.secondaryRateLimitPercent ?? -1) >= 0
                                    Layout.fillWidth: true
                                    spacing: Style.marginXS

                                    RowLayout {
                                        Layout.fillWidth: true
                                        NText {
                                            text: root.selectedProvider?.secondaryRateLimitLabel ?? ""
                                            pointSize: Style.fontSizeS
                                            color: Color.mOnSurfaceVariant
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        NText {
                                            text: {
                                                const u = root.selectedProvider?.secondaryRateLimitPercent ?? -1;
                                                if (u < 0)
                                                    return "\u2014";
                                                const mode = mainInstance?.usageDisplayMode ?? "usage";
                                                const val = mode === "remaining" ? (1.0 - u) : u;
                                                return Math.round(val * 100) + "%";
                                            }
                                            pointSize: Style.fontSizeS
                                            font.weight: Style.fontWeightBold
                                            color: {
                                                const u = root.selectedProvider?.secondaryRateLimitPercent ?? 0;
                                                const mode = mainInstance?.usageDisplayMode ?? "usage";
                                                if (mode === "remaining") {
                                                    if (u >= 0.9) return Color.mError;
                                                    if (u >= 0.7) return root.usageWarnColor;
                                                    return Color.mOnSurface;
                                                }
                                                if (u >= 0.9) return Color.mError;
                                                if (u >= 0.7) return root.usageWarnColor;
                                                return Color.mOnSurface;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 8
                                        color: Qt.alpha(Color.mOutline, 0.2)
                                        radius: Style.radiusXXS

                                        Rectangle {
                                            anchors {
                                                left: parent.left
                                                top: parent.top
                                                bottom: parent.bottom
                                            }
                                            radius: Style.radiusXXS
                                            color: {
                                                const u = root.selectedProvider?.secondaryRateLimitPercent ?? 0;
                                                if (u >= 0.9)
                                                    return Color.mError;
                                                if (u >= 0.7)
                                                    return root.usageWarnColor;
                                                return Color.mPrimary;
                                            }
                                            width: {
                                                const u = root.selectedProvider?.secondaryRateLimitPercent ?? 0;
                                                const mode = mainInstance?.usageDisplayMode ?? "usage";
                                                const val = mode === "remaining" ? (1.0 - u) : u;
                                                return parent.width * Math.min(1.0, Math.max(0, val));
                                            }

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: Style.animationNormal
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }

                                    NText {
                                        visible: (root.selectedProvider?.secondaryRateLimitResetAt ?? "") !== ""
                                        text: (pluginApi?.tr("panel.resets_in") ?? "Resets in {time}").replace("{time}", (root.selectedProvider?.formatResetTime(root.selectedProvider?.secondaryRateLimitResetAt ?? "") ?? ""))
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: (root.selectedProvider?.ready ?? false) && (root.selectedProvider?.hasLocalStats ?? false)
                        Layout.fillWidth: true
                        color: root.sectionBackgroundColor
                        radius: Style.radiusS
                        implicitHeight: todayColumn.implicitHeight + Style.marginXL

                        ColumnLayout {
                            id: todayColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: Style.marginL
                            }
                            spacing: Style.marginM

                            NText {
                                text: pluginApi?.tr("panel.today_title") ?? "Today"
                                pointSize: Style.fontSizeL
                                font.weight: Style.fontWeightSemiBold
                                color: Color.mPrimary
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginXL

                                ColumnLayout {
                                    spacing: Style.marginXXS
                                    NText {
                                        text: String(root.selectedProvider?.todayPrompts ?? 0)
                                        pointSize: Style.fontSizeXXL
                                        font.weight: Style.fontWeightBold
                                        color: Color.mOnSurface
                                    }
                                    NText {
                                        text: pluginApi?.tr("panel.prompts") ?? "prompts"
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                }

                                ColumnLayout {
                                    spacing: Style.marginXXS
                                    NText {
                                        text: String(root.selectedProvider?.todaySessions ?? 0)
                                        pointSize: Style.fontSizeXXL
                                        font.weight: Style.fontWeightBold
                                        color: Color.mOnSurface
                                    }
                                    NText {
                                        text: pluginApi?.tr("panel.sessions") ?? "sessions"
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
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

                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Style.marginS

                                    NText {
                                        text: mainInstance?.friendlyModelName(modelData.modelId) ?? modelData.modelId
                                        pointSize: Style.fontSizeS
                                        color: Color.mOnSurfaceVariant
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    NText {
                                        text: (mainInstance?.formatTokenCount(modelData.count) ?? "0") + " " + (pluginApi?.tr("panel.tokens") ?? "tokens")
                                        pointSize: Style.fontSizeS
                                        font.weight: Style.fontWeightSemiBold
                                        color: Color.mOnSurface
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: (root.selectedProvider?.recentDays ?? []).length > 0
                        Layout.fillWidth: true
                        color: root.sectionBackgroundColor
                        radius: Style.radiusS
                        implicitHeight: weekColumn.implicitHeight + Style.marginXL

                        ColumnLayout {
                            id: weekColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: Style.marginL
                            }
                            spacing: Style.marginS

                            NText {
                                text: pluginApi?.tr("panel.last_7_days") ?? "Last 7 Days"
                                pointSize: Style.fontSizeL
                                font.weight: Style.fontWeightSemiBold
                                color: Color.mPrimary
                            }

                            Repeater {
                                model: root.selectedProvider?.recentDays ?? []

                                RowLayout {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: Style.marginS

                                    NText {
                                        text: {
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
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                        Layout.preferredWidth: 55
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 12
                                        color: Qt.alpha(Color.mOutline, 0.2)
                                        radius: Style.radiusXXS

                                        Rectangle {
                                            anchors {
                                                left: parent.left
                                                top: parent.top
                                                bottom: parent.bottom
                                            }
                                            radius: Style.radiusXXS
                                            color: Color.mPrimary
                                            width: {
                                                const days = root.selectedProvider?.recentDays ?? [];
                                                let maxCount = 1;
                                                for (let i = 0; i < days.length; i++) {
                                                    if ((days[i]?.messageCount ?? 0) > maxCount)
                                                        maxCount = days[i].messageCount;
                                                }
                                                const count = modelData?.messageCount ?? 0;
                                                return parent.width * (count / maxCount);
                                            }

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: Style.animationNormal
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }

                                    NText {
                                        text: mainInstance?.formatTokenCount(modelData?.messageCount ?? 0) ?? "0"
                                        pointSize: Style.fontSizeXS
                                        font.weight: Style.fontWeightSemiBold
                                        color: Color.mOnSurface
                                        Layout.preferredWidth: 30
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: {
                            const usage = root.selectedProvider?.modelUsage ?? {};
                            return Object.keys(usage).length > 0;
                        }
                        Layout.fillWidth: true
                        color: root.sectionBackgroundColor
                        radius: Style.radiusS
                        implicitHeight: allTimeColumn.implicitHeight + Style.marginXL

                        ColumnLayout {
                            id: allTimeColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: Style.marginL
                            }
                            spacing: Style.marginM

                            NText {
                                text: pluginApi?.tr("panel.all_time") ?? "All-Time"
                                pointSize: Style.fontSizeL
                                font.weight: Style.fontWeightSemiBold
                                color: Color.mPrimary
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginXL

                                ColumnLayout {
                                    spacing: Style.marginXXS
                                    NText {
                                        text: mainInstance?.formatTokenCount(root.selectedProvider?.totalPrompts ?? 0) ?? "0"
                                        pointSize: Style.fontSizeXL
                                        font.weight: Style.fontWeightBold
                                        color: Color.mOnSurface
                                    }
                                    NText {
                                        text: pluginApi?.tr("panel.messages") ?? "messages"
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                }

                                ColumnLayout {
                                    spacing: Style.marginXXS
                                    NText {
                                        text: String(root.selectedProvider?.totalSessions ?? 0)
                                        pointSize: Style.fontSizeXL
                                        font.weight: Style.fontWeightBold
                                        color: Color.mOnSurface
                                    }
                                    NText {
                                        text: pluginApi?.tr("panel.sessions") ?? "sessions"
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Color.mOutline
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

                                ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Style.marginXS

                                    NText {
                                        text: mainInstance?.friendlyModelName(modelData.modelId) ?? modelData.modelId
                                        pointSize: Style.fontSizeM
                                        font.weight: Style.fontWeightSemiBold
                                        color: Color.mOnSurface
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: Style.marginM
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

                                    Item {
                                        height: Style.marginXS
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
