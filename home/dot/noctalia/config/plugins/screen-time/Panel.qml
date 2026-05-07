import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 440 * Style.uiScaleRatio
    property real contentPreferredHeight: 680 * Style.uiScaleRatio
    readonly property color cardColor: Color.mSurfaceVariant
    readonly property color hoverColor: Qt.alpha(Color.mPrimary, 0.10)
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
                width: parent.width
                anchors.margins: Style.marginL
                spacing: Style.marginL

                Rectangle {
                    Layout.fillWidth: true
                    radius: Style.radiusS
                    color: root.cardColor
                    implicitHeight: tabsRow.implicitHeight + Style.marginM * 2

                    RowLayout {
                        id: tabsRow
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: Style.marginM
                        }
                        spacing: Style.marginS

                        SegmentButton {
                            Layout.fillWidth: true
                            label: mainInstance?.modeLabel("day") ?? "日"
                            checked: (mainInstance?.mode ?? "day") === "day"
                            onClicked: mainInstance?.setMode("day")
                        }
                        SegmentButton {
                            Layout.fillWidth: true
                            label: mainInstance?.modeLabel("week") ?? "周"
                            checked: (mainInstance?.mode ?? "day") === "week"
                            onClicked: mainInstance?.setMode("week")
                        }
                        SegmentButton {
                            Layout.fillWidth: true
                            label: mainInstance?.modeLabel("month") ?? "月"
                            checked: (mainInstance?.mode ?? "day") === "month"
                            onClicked: mainInstance?.setMode("month")
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Style.radiusS
                    color: root.cardColor
                    implicitHeight: heroContent.implicitHeight + Style.marginXL * 2
                    border.color: Qt.alpha(Color.mPrimary, 0.20)
                    border.width: 1

                    ColumnLayout {
                        id: heroContent
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Style.marginL
                        }
                        spacing: Style.marginL

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginM

                            RangePill {
                                Layout.fillWidth: true
                                label: mainInstance?.rangeLabel(mainInstance?.range ?? "calendar") ?? "今日"
                                onPrevious: mainInstance?.toggleRange()
                                onNext: mainInstance?.toggleRange()
                            }

                            NIconButton {
                                icon: "refresh"
                                baseSize: Style.baseWidgetSize * 0.78
                                onClicked: mainInstance?.refresh()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginXS

                            NText {
                                text: mainInstance?.title ?? "屏幕使用时长"
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            NText {
                                text: mainInstance?.primaryLabel ?? "0分钟"
                                pointSize: Style.fontSizeXXXL
                                font.weight: Style.fontWeightBold
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                            }

                            NText {
                                text: mainInstance?.comparisonLabel ?? ""
                                pointSize: Style.fontSizeS
                                color: Color.mPrimary
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginM

                            InfoChip {
                                Layout.fillWidth: true
                                label: pluginApi?.tr("panel.current_app") ?? "Current app"
                                value: (mainInstance?.currentApp ?? "") !== "" ? mainInstance.currentApp : (pluginApi?.tr("general.none") ?? "None")
                                accent: Color.mPrimary
                            }

                            InfoChip {
                                Layout.fillWidth: true
                                label: pluginApi?.tr("panel.afk") ?? "AFK"
                                value: mainInstance?.formatDuration(mainInstance.afkSeconds) ?? "0m"
                                accent: Color.mOnSurfaceVariant
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Style.radiusS
                    color: root.cardColor
                    implicitHeight: chartContent.implicitHeight + Style.marginXL

                    ColumnLayout {
                        id: chartContent
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Style.marginL
                        }
                        spacing: Style.marginM

                        RowLayout {
                            Layout.fillWidth: true

                            NText {
                                text: pluginApi?.tr("panel.chart") ?? "统计图表"
                                pointSize: Style.fontSizeL
                                font.weight: Style.fontWeightBold
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                            }

                            NText {
                                text: mainInstance?.formatTimestamp(mainInstance.lastUpdated) ?? ""
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurfaceVariant
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 124 * Style.uiScaleRatio
                            spacing: (mainInstance?.mode ?? "day") === "month" ? Style.marginXXS : Style.marginS

                            Repeater {
                                model: mainInstance?.chart ?? []

                                ColumnLayout {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: Style.marginXS

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            width: Math.max(4 * Style.uiScaleRatio, Math.min(18 * Style.uiScaleRatio, parent.width * 0.68))
                                            height: Math.max(7 * Style.uiScaleRatio, parent.height * (mainInstance?.chartShare(modelData.seconds ?? 0) ?? 0))
                                            radius: width / 2
                                            color: (modelData.seconds ?? 0) > 0 ? Color.mPrimary : root.outlineWash
                                        }
                                    }

                                    NText {
                                        text: root.shouldShowChartLabel(index) ? (modelData.label ?? "") : ""
                                        pointSize: Style.fontSizeXXS
                                        color: Color.mOnSurfaceVariant
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Style.radiusS
                    color: root.cardColor
                    implicitHeight: appsContent.implicitHeight + Style.marginXL

                    ColumnLayout {
                        id: appsContent
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Style.marginL
                        }
                        spacing: Style.marginM

                        NText {
                            text: mainInstance?.appListTitle ?? "应用使用情况"
                            pointSize: Style.fontSizeL
                            font.weight: Style.fontWeightBold
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        Repeater {
                            model: mainInstance?.visibleApps() ?? []

                            AppRow {
                                required property var modelData
                                Layout.fillWidth: true
                                appName: modelData.displayName ?? modelData.app ?? "Unknown"
                                seconds: modelData.seconds ?? 0
                                share: mainInstance?.appShare(modelData.seconds ?? 0) ?? 0
                                initial: mainInstance?.appInitial(modelData.displayName ?? modelData.app) ?? "?"
                            }
                        }

                        NText {
                            visible: (mainInstance?.visibleApps() ?? []).length === 0
                            text: pluginApi?.tr("panel.empty") ?? "No activity summary yet."
                            pointSize: Style.fontSizeM
                            color: Color.mOnSurfaceVariant
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            Layout.topMargin: Style.marginL
                        }
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

    component SegmentButton: Rectangle {
        property string label: ""
        property bool checked: false
        signal clicked()

        radius: Style.radiusS
        color: checked ? Color.mPrimary : "transparent"
        implicitHeight: tabText.implicitHeight + Style.marginM

        NText {
            id: tabText
            anchors.centerIn: parent
            text: label
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightSemiBold
            color: checked ? Color.mOnPrimary : Color.mOnSurfaceVariant
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component RangePill: Rectangle {
        property string label: ""
        signal previous()
        signal next()

        radius: Style.radiusS
        color: Qt.alpha(Color.mPrimary, 0.12)
        implicitHeight: pillRow.implicitHeight + Style.marginM

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: Style.marginM

            NIconButton {
                icon: "chevron-left"
                baseSize: Style.baseWidgetSize * 0.68
                onClicked: previous()
            }

            NText {
                text: label
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
                color: Color.mPrimary
            }

            NIconButton {
                icon: "chevron-right"
                baseSize: Style.baseWidgetSize * 0.68
                onClicked: next()
            }
        }
    }

    component InfoChip: Rectangle {
        property string label: ""
        property string value: ""
        property color accent: Color.mPrimary

        radius: Style.radiusS
        color: Qt.alpha(accent, 0.10)
        implicitHeight: chipColumn.implicitHeight + Style.marginM * 2

        ColumnLayout {
            id: chipColumn
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: Style.marginM
            }
            spacing: Style.marginXXS

            NText {
                text: label
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true
            }

            NText {
                text: value
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    component AppRow: Rectangle {
        property string appName: "Unknown"
        property int seconds: 0
        property real share: 0
        property string initial: "?"

        radius: Style.radiusS
        color: Qt.alpha(Color.mSurface, 0.58)
        implicitHeight: appColumn.implicitHeight + Style.marginM * 2

        ColumnLayout {
            id: appColumn
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: Style.marginM
            }
            spacing: Style.marginXS

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                Rectangle {
                    width: 34 * Style.uiScaleRatio
                    height: width
                    radius: Style.radiusS
                    color: Qt.alpha(Color.mPrimary, 0.12)

                    NText {
                        anchors.centerIn: parent
                        text: initial
                        pointSize: Style.fontSizeS
                        font.weight: Style.fontWeightBold
                        color: Color.mPrimary
                    }
                }

                NText {
                    text: appName
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                NText {
                    text: mainInstance?.formatDuration(seconds) ?? "0m"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 7 * Style.uiScaleRatio
                radius: height / 2
                color: root.outlineWash

                Rectangle {
                    width: parent.width * share
                    height: parent.height
                    radius: parent.radius
                    color: Color.mPrimary
                }
            }
        }
    }
}
