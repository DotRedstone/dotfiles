import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property var mainInstance: pluginApi?.mainInstance

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    property string displayText: {
        if (!mainInstance?.ready)
            return "AW";
        if ((mainInstance?.barDisplayMode ?? "duration") === "current" && (mainInstance?.showCurrentApp ?? true) && (mainInstance?.currentApp ?? "") !== "")
            return mainInstance.shortAppName(mainInstance.currentApp, 12);
        return mainInstance?.formatDuration(mainInstance.todayTotalSeconds) ?? "0m";
    }

    property string tooltipText: {
        if (!mainInstance?.ready)
            return pluginApi?.tr("bar.waiting") ?? "Waiting for ActivityWatch";
        const total = mainInstance.formatDuration(mainInstance.todayTotalSeconds);
        const afk = mainInstance.formatDuration(mainInstance.afkSeconds);
        const current = mainInstance.currentApp ? (" · " + (pluginApi?.tr("bar.current") ?? "Current") + ": " + mainInstance.currentApp) : "";
        return (pluginApi?.tr("bar.today") ?? "Today") + ": " + total + " · AFK: " + afk + current;
    }

    readonly property real contentWidth: isBarVertical ? capsuleHeight : content.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: isBarVertical ? content.implicitHeight + Style.marginM * 2 : capsuleHeight

    anchors.centerIn: parent
    implicitWidth: contentWidth
    implicitHeight: contentHeight

    NPopupContextMenu {
        id: contextMenu
        screen: root.screen
        model: [
            { "label": pluginApi?.tr("menu.refresh") ?? "Refresh", "action": "refresh", "icon": "refresh" },
            { "label": pluginApi?.tr("menu.settings") ?? "Widget Settings", "action": "settings", "icon": "settings" }
        ]
        onTriggered: (action, item) => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);
            if (action === "refresh")
                mainInstance?.refresh();
            else if (action === "settings")
                BarService.openPluginSettings(root.screen, pluginApi.manifest);
        }
    }

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        radius: Style.radiusL
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        Item {
            id: content
            anchors.centerIn: parent
            implicitWidth: rowLayout.visible ? rowLayout.implicitWidth : colLayout.implicitWidth
            implicitHeight: rowLayout.visible ? rowLayout.implicitHeight : colLayout.implicitHeight

            RowLayout {
                id: rowLayout
                visible: !root.isBarVertical
                spacing: Style.marginS

                NIcon {
                    icon: "chart-pie"
                    pointSize: root.barFontSize
                    applyUiScale: false
                    color: mainInstance?.ok ? Color.mPrimary : Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignVCenter
                }

                NText {
                    text: root.displayText
                    pointSize: root.barFontSize
                    applyUiScale: false
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            ColumnLayout {
                id: colLayout
                visible: root.isBarVertical
                spacing: Style.marginXS

                NIcon {
                    icon: "chart-pie"
                    pointSize: root.barFontSize
                    applyUiScale: false
                    color: mainInstance?.ok ? Color.mPrimary : Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                }

                NText {
                    text: root.displayText
                    pointSize: root.barFontSize
                    applyUiScale: false
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                TooltipService.hide();
                pluginApi?.togglePanel(root.screen, root);
            } else if (mouse.button === Qt.RightButton) {
                TooltipService.hide();
                PanelService.showContextMenu(contextMenu, root, root.screen);
            }
        }
        onEntered: TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screenName))
        onExited: TooltipService.hide()
    }
}
