import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    property real value: 0
    property color color: root.autoColor()
    property color trackColor: Qt.alpha(Color.mOutline, 0.22)
    property real barHeight: 7 * Style.uiScaleRatio
    property bool animated: true
    property real warningThreshold: 0.7
    property real dangerThreshold: 0.9
    property color fillColor: color

    Layout.fillWidth: true
    implicitHeight: barHeight

    function clampedValue() {
        return Math.max(0, Math.min(1, value));
    }

    function autoColor() {
        const v = clampedValue();
        if (v >= dangerThreshold)
            return Color.mError;
        if (v >= warningThreshold)
            return Qt.alpha(Color.mError, 0.72);
        return Color.mPrimary;
    }

    function effectiveHeight() {
        return height > 0 ? height : implicitHeight;
    }

    NBox {
        anchors.fill: parent
        radius: root.effectiveHeight() / 2
        color: root.trackColor
        clip: true

        NBox {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.clampedValue()
            radius: parent.radius
            color: root.fillColor

            Behavior on width {
                enabled: root.animated
                NumberAnimation {
                    duration: Style.animationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
