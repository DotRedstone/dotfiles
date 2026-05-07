import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
    id: root

    default property alias content: contentLayout.data
    property real padding: Style.marginL
    property real cardRadius: Style.radiusS
    property color cardColor: Color.mSurfaceVariant
    property color cardBorderColor: Qt.alpha(Color.mOutline, 0.18)
    property bool bordered: false

    Layout.fillWidth: true
    radius: cardRadius
    color: cardColor
    border.color: bordered ? cardBorderColor : "transparent"
    border.width: bordered ? 1 : 0
    implicitHeight: contentLayout.implicitHeight + padding * 2
    clip: true

    ColumnLayout {
        id: contentLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.padding
        }
        spacing: Style.marginM
    }
}
