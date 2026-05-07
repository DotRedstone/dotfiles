import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    property real value: 0
    property color trackColor: Qt.alpha(Color.mOutline, 0.22)
    property color fillColor: Color.mPrimary
    property real barHeight: 7 * Style.uiScaleRatio

    Layout.fillWidth: true
    height: barHeight
    radius: height / 2
    color: trackColor
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, root.value))
        radius: parent.radius
        color: root.fillColor
    }
}
