import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property string icon: "inbox"
    property string title: ""
    property string description: ""
    property string actionText: ""
    signal actionClicked()

    Layout.fillWidth: true
    spacing: Style.marginS

    NIcon {
        visible: root.icon !== ""
        icon: root.icon
        pointSize: Style.fontSizeXXXL
        color: Color.mOnSurfaceVariant
        Layout.alignment: Qt.AlignHCenter
    }

    NText {
        text: root.title
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        visible: root.title !== ""
    }

    NText {
        text: root.description
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        visible: root.description !== ""
    }

    NButton {
        visible: root.actionText !== ""
        text: root.actionText
        Layout.alignment: Qt.AlignHCenter
        onClicked: root.actionClicked()
    }
}
