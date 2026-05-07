import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var model: []
    property real maxValue: 0
    property int selectedIndex: -1
    property bool compact: false
    property color barColor: Color.mPrimary
    property color emptyColor: Qt.alpha(Color.mOutline, 0.20)
    property real chartHeight: (compact ? 92 : 124) * Style.uiScaleRatio
    property real labelHeight: 14 * Style.uiScaleRatio
    property bool showTooltip: true
    property string tooltipText: ""
    property int hoveredIndex: -1
    property real hoveredX: 0
    property real hoveredY: 0
    property color tooltipColor: Color.mSurface
    property color tooltipBorderColor: Qt.alpha(Color.mOutline, 0.28)

    Layout.fillWidth: true
    implicitHeight: contentLayout.implicitHeight

    onModelChanged: {
        hoveredIndex = -1;
    }

    function itemValue(item) {
        return item.value ?? item.seconds ?? 0;
    }

    function tooltipFor(item) {
        if (!item)
            return "";

        const tooltip = item.tooltip ?? "";
        if (tooltip !== "")
            return String(tooltip);

        const label = item.label ?? "";
        const value = item.value ?? item.seconds ?? 0;
        return label !== "" ? (label + " · " + String(value)) : String(value);
    }

    function tooltipTextForHovered() {
        if (tooltipText !== "")
            return tooltipText;
        if (hoveredIndex < 0 || hoveredIndex >= model.length)
            return "";
        return tooltipFor(model[hoveredIndex]);
    }

    function resolvedMax() {
        if (maxValue > 0)
            return maxValue;
        let maxSeen = 1;
        for (let i = 0; i < model.length; i++)
            maxSeen = Math.max(maxSeen, itemValue(model[i]));
        return maxSeen;
    }

    function slotWidth() {
        return model.length > 0 ? (chartArea.width / model.length) : 0;
    }

    function barWidthForSlot(slot) {
        const maxWidth = compact ? 10 * Style.uiScaleRatio : 14 * Style.uiScaleRatio;
        return Math.max(3 * Style.uiScaleRatio, Math.min(maxWidth, slot * 0.42));
    }

    function barHeightFor(item, availableHeight) {
        const value = itemValue(item);
        if (value <= 0)
            return Math.max(2 * Style.uiScaleRatio, Style.capsuleBorderWidth || 1);

        const ratio = value / resolvedMax();
        return Math.max(5 * Style.uiScaleRatio, availableHeight * Math.max(0, Math.min(1, ratio)));
    }

    function updateTooltipPosition(barItem) {
        const pos = barItem.mapToItem(root, barItem.width / 2, 0);
        hoveredX = pos.x;
        hoveredY = pos.y;
    }

    ColumnLayout {
        id: contentLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.marginXS

        Item {
            id: chartArea

            Layout.fillWidth: true
            Layout.preferredHeight: root.chartHeight

            Repeater {
                model: root.model

                Item {
                    required property var modelData
                    required property int index
                    readonly property real slot: root.slotWidth()
                    readonly property real labelGap: Style.marginXXS
                    readonly property real barAreaHeight: Math.max(1, chartArea.height - root.labelHeight - labelGap)

                    x: index * slot
                    y: 0
                    width: slot
                    height: chartArea.height

                    Item {
                        id: barArea

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: parent.barAreaHeight

                        NBox {
                            id: bar
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: root.barWidthForSlot(parent.width)
                            height: root.barHeightFor(modelData, parent.height)
                            radius: width / 2
                            color: root.itemValue(modelData) > 0 ? root.barColor : root.emptyColor
                            opacity: root.selectedIndex < 0 || root.selectedIndex === index ? 1 : 0.52
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: root.showTooltip
                            acceptedButtons: Qt.NoButton
                            onEntered: {
                                root.hoveredIndex = index;
                                root.updateTooltipPosition(bar);
                            }
                            onPositionChanged: {
                                root.updateTooltipPosition(bar);
                            }
                            onExited: {
                                if (root.hoveredIndex === index)
                                    root.hoveredIndex = -1;
                            }
                        }
                    }

                    NText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: root.labelHeight
                        text: modelData.label ?? ""
                        pointSize: Style.fontSizeXXS
                        color: Color.mOnSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    NBox {
        z: 20
        width: Math.max(0, Math.min(root.width, Math.max(92 * Style.uiScaleRatio, tooltipLabel.implicitWidth + Style.marginM * 2)))
        height: Math.max(24 * Style.uiScaleRatio, tooltipLabel.implicitHeight + Style.marginXS * 2)
        x: Math.max(0, Math.min(root.width - width, root.hoveredX - width / 2))
        y: Math.max(0, root.hoveredY - height - Style.marginXS)
        radius: Style.radiusS
        color: root.tooltipColor
        border.color: root.tooltipBorderColor
        border.width: 1
        opacity: root.showTooltip && root.hoveredIndex >= 0 && root.tooltipTextForHovered() !== "" ? 1 : 0
        visible: opacity > 0

        NText {
            id: tooltipLabel
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Style.marginM)
            text: root.tooltipTextForHovered()
            pointSize: Style.fontSizeXS
            color: Color.mOnSurface
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
