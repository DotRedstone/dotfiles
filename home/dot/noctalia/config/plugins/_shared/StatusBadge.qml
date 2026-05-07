import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
    id: root

    property string label: ""
    property string icon: ""
    property color accentColor: Color.mPrimary
    property color textColor: Color.mOnSurface
    property bool filled: false

    radius: Style.radiusS
    color: filled ? accentColor : Qt.alpha(accentColor, 0.12)
    implicitWidth: badgeRow.implicitWidth + Style.marginM * 2
    implicitHeight: badgeRow.implicitHeight + Style.marginS

    RowLayout {
        id: badgeRow
        anchors.centerIn: parent
        spacing: Style.marginXS

        NIcon {
            visible: root.icon !== ""
            icon: root.icon
            pointSize: Style.fontSizeS
            color: root.filled ? Color.mOnPrimary : root.accentColor
        }

        NText {
            text: root.label
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightSemiBold
            color: root.filled ? Color.mOnPrimary : root.textColor
            elide: Text.ElideRight
        }
    }
}
