import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import "../_shared" as Shared

Item {
    id: root

    property var pluginApi: null
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 440 * Style.uiScaleRatio
    property real contentPreferredHeight: 680 * Style.uiScaleRatio
    readonly property color outlineWash: Qt.alpha(Color.mOutline, 0.22)

    anchors.fill: parent

    onVisibleChanged: {
        if (visible)
            mainInstance?.refresh();
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        Flickable {
            anchors.fill: parent
            contentHeight: contentLayout.implicitHeight + Style.marginL * 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentLayout
                x: Style.marginL
                y: Style.marginL
                width: parent.width - Style.marginL * 2
                spacing: Style.marginL

                Shared.SegmentedControl {
                    options: [
                        { "key": "day", "label": mainInstance?.modeLabel("day") ?? "日" },
                        { "key": "week", "label": mainInstance?.modeLabel("week") ?? "周" },
                        { "key": "month", "label": mainInstance?.modeLabel("month") ?? "月" }
                    ]
                    currentKey: mainInstance?.mode ?? "day"
                    onSelected: key => mainInstance?.setMode(key)
                }

                Shared.PluginCard {
                    padding: Style.marginL

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            NIconButton {
                                icon: "chevron-left"
                                baseSize: Style.baseWidgetSize * 0.68
                                onClicked: mainInstance?.toggleRange()
                            }

                            Shared.StatusBadge {
                                Layout.fillWidth: true
                                label: mainInstance?.rangeLabel(mainInstance?.range ?? "calendar") ?? "今日"
                                icon: "calendar-stats"
                                accentColor: Color.mPrimary
                                textColor: Color.mPrimary
                            }

                            NIconButton {
                                icon: "chevron-right"
                                baseSize: Style.baseWidgetSize * 0.68
                                onClicked: mainInstance?.toggleRange()
                            }
                        }

                        NIconButton {
                            icon: "refresh"
                            baseSize: Style.baseWidgetSize * 0.78
                            onClicked: mainInstance?.refresh()
                        }
                    }

                    Shared.SectionHeader {
                        title: mainInstance?.title ?? "屏幕使用时长"
                        subtitle: mainInstance?.comparisonLabel ?? ""
                        icon: "clock-hour-4"
                        meta: mainInstance?.formatTimestamp(mainInstance.lastUpdated) ?? ""
                    }

                    NText {
                        text: mainInstance?.primaryLabel ?? "0分钟"
                        pointSize: Style.fontSizeXXXL
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        Shared.MetricRow {
                            Layout.fillWidth: true
                            showBackground: true
                            icon: "app-window"
                            label: pluginApi?.tr("panel.current_app") ?? "Current app"
                            value: (mainInstance?.currentApp ?? "") !== "" ? mainInstance.currentApp : (pluginApi?.tr("general.none") ?? "None")
                            accentColor: Color.mPrimary
                        }

                        Shared.MetricRow {
                            Layout.fillWidth: true
                            showBackground: true
                            icon: "clock-pause"
                            label: pluginApi?.tr("panel.afk") ?? "AFK"
                            value: mainInstance?.formatDuration(mainInstance.afkSeconds) ?? "0m"
                            accentColor: Color.mOnSurfaceVariant
                        }
                    }

                    Shared.StatusBadge {
                        label: mainInstance?.sourceStatusText ?? "ActivityWatch"
                        icon: (mainInstance?.ok ?? false) ? "circle-check" : "alert-circle"
                        accentColor: (mainInstance?.ok ?? false) ? Color.mPrimary : Color.mError
                        textColor: (mainInstance?.ok ?? false) ? Color.mPrimary : Color.mError
                    }
                }

                Shared.PluginCard {
                    Shared.SectionHeader {
                        title: pluginApi?.tr("panel.chart") ?? "统计图表"
                        icon: "chart-bar"
                        meta: mainInstance?.formatTimestamp(mainInstance.lastUpdated) ?? ""
                    }

                    Shared.BarChart {
                        model: root.chartModelForDisplay()
                        compact: (mainInstance?.mode ?? "day") === "month"
                    }
                }

                Shared.PluginCard {
                    Shared.SectionHeader {
                        title: mainInstance?.appListTitle ?? "应用使用情况"
                        icon: "apps"
                    }

                    Repeater {
                        model: mainInstance?.visibleApps() ?? []

                        Shared.MetricRow {
                            required property var modelData
                            Layout.fillWidth: true
                            label: modelData.displayName ?? modelData.app ?? "Unknown"
                            value: mainInstance?.formatDuration(modelData.seconds ?? 0) ?? "0m"
                            progress: mainInstance?.appShare(modelData.seconds ?? 0) ?? 0
                            leadingText: mainInstance?.appInitial(modelData.displayName ?? modelData.app) ?? "?"
                            accentColor: Color.mPrimary
                        }
                    }

                    Shared.EmptyState {
                        visible: (mainInstance?.visibleApps() ?? []).length === 0
                        icon: "chart-dots"
                        title: pluginApi?.tr("panel.empty") ?? "No activity summary yet."
                        description: mainInstance?.sourceStatusText ?? ""
                        Layout.topMargin: Style.marginL
                    }
                }
            }
        }
    }

    function shouldShowChartLabel(index) {
        const mode = mainInstance?.mode ?? "day";
        if (mode === "week")
            return true;
        if (mode === "day")
            return index % 4 === 0;
        const chartLength = (mainInstance?.chart ?? []).length;
        return index === 0 || index === chartLength - 1 || index % 5 === 0;
    }

    function chartModelForDisplay() {
        const chart = mainInstance?.chart ?? [];
        const result = [];
        for (let i = 0; i < chart.length; i++) {
            result.push({
                label: root.shouldShowChartLabel(i) ? (chart[i].label ?? "") : "",
                value: chart[i].seconds ?? chart[i].value ?? 0
            });
        }
        return result;
    }
}
