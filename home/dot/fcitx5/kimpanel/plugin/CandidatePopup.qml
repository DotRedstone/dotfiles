import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

// [Popup] Per-screen candidate surface; only the card region accepts input.
PanelWindow {
    id: win

    property var daemon
    readonly property var panel: daemon.panel
    readonly property var anchor: daemon.anchor
    readonly property bool vertical: panel.layout === 1
    readonly property int count: panel.candidates.length

    WlrLayershell.namespace: "dms-fcitx-kimpanel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"
    mask: Region {
        item: card
    }

    // [Screen] Show on the screen holding the anchor, else the focused output
    readonly property bool onThisScreen: {
        if (!screen)
            return false;
        if (anchor)
            return anchor.x >= screen.x && anchor.x < screen.x + screen.width && anchor.y >= screen.y && anchor.y < screen.y + screen.height;
        if (daemon.focusedOutput)
            return screen.name === daemon.focusedOutput;
        return screen === Quickshell.screens[0];
    }

    // [Placement] Lock left-top anchor per composition session to prevent horizontal drift
    readonly property real edge: Theme.spacingM
    readonly property real gap: Theme.spacingXS + 2
    property real lockedX: 0
    property real lockedY: 0
    property real lockedH: 20
    property bool hasLockedAnchor: false

    function syncAnchor(reset) {
        if (!screen)
            return;
        if (anchor) {
            const ax = anchor.x - screen.x;
            const ay = anchor.y - screen.y;
            if (reset || !hasLockedAnchor || Math.abs(ay - lockedY) > 24 || Math.abs(ax - lockedX) > 180) {
                lockedX = ax;
                lockedY = ay;
                lockedH = Math.max(anchor.h, 16);
                hasLockedAnchor = true;
            }
        } else if (reset) {
            const r = daemon.focusedWindowRect;
            const centerX = r ? (r.x - screen.x + r.w / 2) : (width / 2);
            const bottomY = r ? (r.y - screen.y + r.h) : height;
            lockedX = Math.round(centerX - 220);
            lockedY = Math.round(Math.min(bottomY, height) - 116);
            lockedH = 0;
            hasLockedAnchor = false;
        }
    }

    onAnchorChanged: {
        if (shown)
            syncAnchor(false);
    }

    // [Visibility] Short hide debounce avoids flicker between keystrokes
    property bool shown: false
    readonly property bool wanted: panel.visible && onThisScreen
    onWantedChanged: {
        if (wanted) {
            const wasHidden = !shown;
            hideDebounce.stop();
            if (wasHidden)
                syncAnchor(true);
            shown = true;
        } else {
            hideDebounce.restart();
        }
    }
    Timer {
        id: hideDebounce
        interval: 40
        onTriggered: {
            win.shown = false;
            win.hasLockedAnchor = false;
        }
    }
    visible: shown || card.opacity > 0

    readonly property real targetX: Math.round(Math.max(edge, Math.min(lockedX, width - card.width - edge)))
    readonly property real targetY: {
        if (hasLockedAnchor) {
            const below = lockedY + lockedH + gap;
            if (below + card.height + edge <= height)
                return Math.round(below);
            return Math.round(Math.max(edge, lockedY - card.height - gap));
        }
        return Math.round(Math.max(edge, Math.min(lockedY, height - card.height - edge)));
    }

    Item {
        id: card

        x: win.targetX
        y: win.targetY
        width: body.implicitWidth + Theme.spacingS * 2
        height: body.implicitHeight + Theme.spacingS * 2
        opacity: win.shown ? 1 : 0

        onWidthChanged: {
            if (win.shown && win.width > 0) {
                const maxLeft = win.width - width - win.edge;
                if (win.lockedX > maxLeft)
                    win.lockedX = Math.max(win.edge, maxLeft);
            }
        }

        readonly property bool settled: win.shown && opacity === 1

        Behavior on opacity {
            NumberAnimation {
                duration: win.shown ? Theme.shortDuration : 70
                easing.type: Theme.standardEasing
            }
        }
        transform: Translate {
            y: win.shown ? 0 : 4
            Behavior on y {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }

        ElevationShadow {
            anchors.fill: parent
            z: -1
            level: Theme.elevationLevel2
            targetRadius: bg.radius
            targetColor: bg.color
            shadowEnabled: Theme.elevationEnabled
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Theme.cornerRadiusL
            color: Theme.withAlpha(Theme.surfaceContainer, 0.97)
            border.width: 1
            border.color: Theme.withAlpha(Theme.outlineVariant, 0.4)
        }

        WheelHandler {
            onWheel: event => {
                if (event.angleDelta.y !== 0)
                    win.daemon.send(event.angleDelta.y > 0 ? "page_up" : "page_down");
            }
        }

        Column {
            id: body
            x: Theme.spacingS
            y: Theme.spacingS
            spacing: Theme.spacingXS

            // [Header] Preedit with caret, aux hint, pager
            Item {
                id: header
                visible: preeditText.text !== "" || auxText.text !== "" || pager.visible
                implicitWidth: headerRow.implicitWidth + (pager.visible ? pager.implicitWidth + Theme.spacingL : 0)
                implicitHeight: Math.max(headerRow.implicitHeight, pager.implicitHeight)
                width: Math.max(implicitWidth, candidates.implicitWidth)

                Row {
                    id: headerRow
                    x: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    Text {
                        id: preeditText
                        text: win.panel.preedit
                        visible: text !== ""
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium - 1

                        TextMetrics {
                            id: caretMetrics
                            font: preeditText.font
                            text: preeditText.text.slice(0, win.panel.caret)
                        }
                        Rectangle {
                            x: caretMetrics.advanceWidth
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1.5
                            height: parent.font.pixelSize + 2
                            radius: 1
                            color: Theme.primary
                        }
                    }

                    Text {
                        id: auxText
                        text: win.panel.aux
                        visible: text !== ""
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    id: pager
                    visible: win.panel.hasPrev || win.panel.hasNext
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Repeater {
                        model: [
                            {
                                "glyph": "‹",
                                "on": win.panel.hasPrev,
                                "cmd": "page_up"
                            },
                            {
                                "glyph": "›",
                                "on": win.panel.hasNext,
                                "cmd": "page_down"
                            }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            width: 20
                            height: 20
                            radius: Theme.cornerRadiusS
                            color: pageMouse.containsMouse && modelData.on ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.glyph
                                color: Theme.surfaceText
                                opacity: parent.modelData.on ? 0.9 : 0.25
                                font.pixelSize: Theme.fontSizeMedium + 2
                            }

                            MouseArea {
                                id: pageMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: parent.modelData.on
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.daemon.send(parent.modelData.cmd)
                            }
                        }
                    }
                }
            }

            // [Candidates] Grid with a sliding selection pill
            Item {
                id: candidates
                visible: win.count > 0
                implicitWidth: grid.implicitWidth
                implicitHeight: grid.implicitHeight

                readonly property real itemHeight: Math.round((Theme.fontSizeMedium + 1) + Theme.spacingXS * 2 + 6)
                readonly property Item active: win.panel.cursor >= 0 && win.panel.cursor < repeater.count ? repeater.itemAt(win.panel.cursor) : null

                Rectangle {
                    id: pill
                    visible: candidates.active !== null
                    x: candidates.active?.x ?? 0
                    y: candidates.active?.y ?? 0
                    width: candidates.active?.width ?? 0
                    height: candidates.active?.height ?? 0
                    radius: Theme.cornerRadiusM
                    color: Theme.primaryContainer

                    Behavior on x {
                        enabled: card.settled
                        NumberAnimation {
                            duration: 100
                            easing.type: Theme.standardEasing
                        }
                    }
                    Behavior on y {
                        enabled: card.settled
                        NumberAnimation {
                            duration: 100
                            easing.type: Theme.standardEasing
                        }
                    }
                    Behavior on width {
                        enabled: card.settled
                        NumberAnimation {
                            duration: 100
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                Grid {
                    id: grid
                    columns: win.vertical ? 1 : Math.max(1, win.count)
                    columnSpacing: Theme.spacingXXS
                    rowSpacing: Theme.spacingXXS

                    Repeater {
                        id: repeater
                        model: win.panel.candidates

                        delegate: Item {
                            id: cand
                            required property int index
                            required property var modelData
                            readonly property bool selected: index === win.panel.cursor

                            width: implicitWidth
                            height: candidates.itemHeight
                            implicitWidth: row.implicitWidth + Theme.spacingS * 2
                            implicitHeight: candidates.itemHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadiusM
                                color: Theme.surfaceText
                                opacity: hover.containsMouse && !cand.selected ? 0.06 : 0
                            }

                            Row {
                                id: row
                                height: parent.height
                                x: Theme.spacingS
                                spacing: Theme.spacingXS + 1

                                Text {
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    text: cand.modelData.label
                                    color: cand.selected ? Theme.onPrimaryContainer : Theme.surfaceVariantText
                                    opacity: cand.selected ? 0.8 : 0.7
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Text {
                                    id: candText
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    text: cand.modelData.text
                                    color: cand.selected ? Theme.onPrimaryContainer : Theme.surfaceText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeMedium + 1
                                    font.weight: cand.selected ? Font.Medium : Font.Normal
                                }
                            }

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.daemon.send("select " + cand.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
