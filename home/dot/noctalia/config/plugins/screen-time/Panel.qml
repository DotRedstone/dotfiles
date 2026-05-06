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
    readonly property color primaryWash: Qt.alpha(Color.mPrimary, 0.14)
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
                    implicitHeight: heroContent.implicitHeight + Style.marginXL * 2
                    border.color: Qt.alpha(Color.mPrimary, 0.26)
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

                            Rectangle {
                                width: 50 * Style.uiScaleRatio
                                height: width
                                radius: width / 2
                                color: root.primaryWash

                                NIcon {
                                    anchors.centerIn: parent
                                    icon: "chart-pie"
                                    pointSize: Style.fontSizeXXL
                                    color: Color.mPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginXXS

                                NText {
                                    text: pluginApi?.tr("panel.title") ?? "Screen Time"
                                    pointSize: Style.fontSizeL
                                    font.weight: Style.fontWeightBold
                                    color: Color.mOnSurface
                                }

                                NText {
                                    text: mainInstance?.sourceStatusText ?? (pluginApi?.tr("status.waiting") ?? "Waiting for ActivityWatch")
                                    pointSize: Style.fontSizeS
                                    color: mainInstance?.ok ? Color.mPrimary : Color.mOnSurfaceVariant
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            NIconButton {
                                icon: "refresh"
                                baseSize: Style.baseWidgetSize * 0.78
                                onClicked: mainInstance?.refresh()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginL

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginXS

                                NText {
                                    text: pluginApi?.tr("panel.today_total") ?? "Today"
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                }

                                NText {
                                    text: mainInstance?.formatDuration(mainInstance.todayTotalSeconds) ?? "0m"
                                    pointSize: Style.fontSizeXXXL
                                    font.weight: Style.fontWeightBold
                                    color: Color.mOnSurface
                                }
                            }

                            Rectangle {
                                visible: (mainInstance?.currentApp ?? "") !== ""
                                radius: Style.radiusS
                                color: Qt.alpha(Color.mPrimary, 0.12)
                                implicitWidth: currentPill.implicitWidth + Style.marginL * 2
                                implicitHeight: currentPill.implicitHeight + Style.marginM

                                RowLayout {
                                    id: currentPill
                                    anchors.centerIn: parent
                                    spacing: Style.marginS

                                    Rectangle {
                                        width: 8 * Style.uiScaleRatio
                                        height: width
                                        radius: width / 2
                                        color: Color.mPrimary
                                    }

                                    NText {
                                        text: mainInstance?.shortAppName(mainInstance.currentApp, 14) ?? ""
                                        pointSize: Style.fontSizeS
                                        font.weight: Style.fontWeightSemiBold
                                        color: Color.mPrimary
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginM

                            StatCard {
                                Layout.fillWidth: true
                                label: pluginApi?.tr("panel.week") ?? "Week"
                                value: mainInstance?.formatDuration(mainInstance.weekTotalSeconds) ?? "0m"
                                subtext: (pluginApi?.tr("panel.afk_short") ?? "AFK") + " " + (mainInstance?.formatDuration(mainInstance.weekAfkSeconds) ?? "0m")
                                accent: Color.mPrimary
                            }

                            StatCard {
                                Layout.fillWidth: true
                                label: pluginApi?.tr("panel.month") ?? "Month"
                                value: mainInstance?.formatDuration(mainInstance.monthTotalSeconds) ?? "0m"
                                subtext: (pluginApi?.tr("panel.afk_short") ?? "AFK") + " " + (mainInstance?.formatDuration(mainInstance.monthAfkSeconds) ?? "0m")
                                accent: Color.mOnSurfaceVariant
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Style.radiusS
                    color: root.cardColor
                    implicitHeight: weekContent.implicitHeight + Style.marginXL

                    ColumnLayout {
                        id: weekContent
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
                                text: pluginApi?.tr("panel.last_7_days") ?? "Last 7 Days"
                                pointSize: Style.fontSizeL
                                font.weight: Style.fontWeightBold
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                            }
                            NText {
                                text: mainInstance?.formatTimestamp(mainInstance.fetchedAt) ?? ""
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurfaceVariant
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 104 * Style.uiScaleRatio
                            spacing: Style.marginS

                            Repeater {
                                model: mainInstance?.dailyTotals ?? []

                                ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: Style.marginXS

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            width: 18 * Style.uiScaleRatio
                                            height: Math.max(8 * Style.uiScaleRatio, parent.height * (mainInstance?.dailyShare(modelData.seconds ?? 0) ?? 0))
                                            radius: width / 2
                                            color: (modelData.seconds ?? 0) > 0 ? Color.mPrimary : root.outlineWash
                                        }
                                    }

                                    NText {
                                        text: modelData.label ?? ""
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                        horizontalAlignment: Text.AlignHCenter
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

                        RowLayout {
                            Layout.fillWidth: true

                            NText {
                                text: pluginApi?.tr("panel.top_apps") ?? "Top Apps"
                                pointSize: Style.fontSizeL
                                font.weight: Style.fontWeightBold
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                            }

                            NText {
                                text: pluginApi?.tr("panel.today") ?? "Today"
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurfaceVariant
                            }
                        }

                        Repeater {
                            model: mainInstance?.visibleTopApps() ?? []

                            AppRow {
                                required property var modelData
                                Layout.fillWidth: true
                                appName: modelData.app ?? "Unknown"
                                seconds: modelData.seconds ?? 0
                                share: mainInstance?.topAppShare(modelData.seconds ?? 0) ?? 0
                                initial: mainInstance?.appInitial(modelData.app) ?? "?"
                            }
                        }

                        NText {
                            visible: (mainInstance?.visibleTopApps() ?? []).length === 0
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

    component StatCard: Rectangle {
        property string label: ""
        property string value: ""
        property string subtext: ""
        property color accent: Color.mPrimary

        radius: Style.radiusS
        color: Qt.alpha(accent, 0.10)
        implicitHeight: statColumn.implicitHeight + Style.marginM * 2

        ColumnLayout {
            id: statColumn
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
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                Layout.fillWidth: true
            }

            NText {
                text: subtext
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
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
