import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var model: []
    property real maxValue: 0
    property int selectedIndex: -1
    property bool compact: false
    property color barColor: Color.mPrimary
    property color emptyColor: Qt.alpha(Color.mOutline, 0.20)
    property real chartHeight: (compact ? 92 : 124) * Style.uiScaleRatio

    Layout.fillWidth: true
    spacing: Style.marginXS

    function itemValue(item) {
        return item.value ?? item.seconds ?? 0;
    }

    function resolvedMax() {
        if (maxValue > 0)
            return maxValue;
        let maxSeen = 1;
        for (let i = 0; i < model.length; i++)
            maxSeen = Math.max(maxSeen, itemValue(model[i]));
        return maxSeen;
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: root.chartHeight
        spacing: root.compact ? Style.marginXXS : Style.marginS

        Repeater {
            model: root.model

            ColumnLayout {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Style.marginXS

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    NBox {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: Math.max(4 * Style.uiScaleRatio, Math.min(root.compact ? 12 * Style.uiScaleRatio : 18 * Style.uiScaleRatio, parent.width * 0.68))
                        height: {
                            const ratio = root.itemValue(modelData) / root.resolvedMax();
                            return Math.max(7 * Style.uiScaleRatio, parent.height * Math.max(0, Math.min(1, ratio)));
                        }
                        radius: width / 2
                        color: root.itemValue(modelData) > 0 ? root.barColor : root.emptyColor
                        opacity: root.selectedIndex < 0 || root.selectedIndex === index ? 1 : 0.52
                    }
                }

                NText {
                    text: modelData.label ?? ""
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
