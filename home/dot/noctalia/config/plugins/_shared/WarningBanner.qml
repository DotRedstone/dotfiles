import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

PluginCard {
    id: root

    property string title: ""
    property string message: ""
    property string icon: root.defaultIcon()

    variant: "warning"
    padding: Style.marginM
    spacing: Style.marginXS
    cardColor: Qt.alpha(root.accentColor(), 0.12)
    outlined: true
    cardBorderColor: Qt.alpha(root.accentColor(), 0.24)

    function accentColor() {
        if (variant === "error")
            return Color.mError;
        if (variant === "info")
            return Color.mPrimary;
        return Color.mError;
    }

    function defaultIcon() {
        if (variant === "error")
            return "alert-circle";
        if (variant === "info")
            return "info-circle";
        return "alert-triangle";
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIcon {
            icon: root.icon
            pointSize: Style.fontSizeL
            color: root.accentColor()
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
                visible: root.title !== ""
                text: root.title
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightSemiBold
                color: root.accentColor()
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            NText {
                visible: root.message !== ""
                text: root.message
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }
}
