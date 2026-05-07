import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

RowLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property string meta: ""
    property string actionText: ""
    property string actionIcon: ""
    signal actionClicked()

    Layout.fillWidth: true
    spacing: Style.marginM

    NIcon {
        visible: root.icon !== ""
        icon: root.icon
        pointSize: Style.fontSizeL
        color: Color.mPrimary
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
            text: root.title
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        NText {
            visible: root.subtitle !== ""
            text: root.subtitle
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    NText {
        visible: root.meta !== "" && root.actionText === "" && root.actionIcon === ""
        text: root.meta
        pointSize: Style.fontSizeXS
        color: Color.mOnSurfaceVariant
        elide: Text.ElideRight
    }

    NButton {
        visible: root.actionText !== ""
        text: root.actionText
        onClicked: root.actionClicked()
    }

    NIconButton {
        visible: root.actionText === "" && root.actionIcon !== ""
        icon: root.actionIcon
        baseSize: Style.baseWidgetSize * 0.78
        onClicked: root.actionClicked()
    }
}
