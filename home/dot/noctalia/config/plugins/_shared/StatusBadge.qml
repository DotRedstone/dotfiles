import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
    id: root

    property string text: ""
    property string label: ""
    property string icon: ""
    property string variant: "primary"
    property bool compact: false
    property color accentColor: root.variantColor()
    property color textColor: root.variantTextColor()
    property bool filled: false

    radius: height / 2
    color: filled ? accentColor : Qt.alpha(accentColor, 0.12)
    implicitWidth: badgeRow.implicitWidth + (compact ? Style.marginS : Style.marginM) * 2
    implicitHeight: badgeRow.implicitHeight + (compact ? Style.marginXS : Style.marginS)

    function variantColor() {
        if (variant === "success" || variant === "primary")
            return Color.mPrimary;
        if (variant === "warning")
            return Color.mError;
        if (variant === "error")
            return Color.mError;
        if (variant === "info")
            return Color.mPrimary;
        return Color.mOnSurfaceVariant;
    }

    function variantTextColor() {
        if (variant === "neutral")
            return Color.mOnSurfaceVariant;
        return accentColor;
    }

    RowLayout {
        id: badgeRow
        anchors.centerIn: parent
        spacing: root.compact ? Style.marginXXS : Style.marginXS

        NIcon {
            visible: root.icon !== ""
            icon: root.icon
            pointSize: root.compact ? Style.fontSizeXS : Style.fontSizeS
            color: root.filled ? Color.mOnPrimary : root.accentColor
        }

        NText {
            text: root.text !== "" ? root.text : root.label
            pointSize: root.compact ? Style.fontSizeXS : Style.fontSizeS
            font.weight: Style.fontWeightSemiBold
            color: root.filled ? Color.mOnPrimary : root.textColor
            elide: Text.ElideRight
        }
    }
}
