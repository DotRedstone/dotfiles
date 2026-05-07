import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
    id: root

    default property alias content: contentLayout.data
    property string variant: "surfaceVariant"
    property bool elevated: false
    property bool outlined: false
    property real padding: Style.marginL
    property real spacing: Style.marginM
    property real cardRadius: Style.radiusS
    property color accentColor: Color.mPrimary
    property color cardColor: root.variantColor()
    property color cardBorderColor: Qt.alpha(Color.mOutline, 0.18)
    property bool bordered: false

    Layout.fillWidth: true
    radius: cardRadius
    color: cardColor
    border.color: (outlined || bordered) ? cardBorderColor : "transparent"
    border.width: (outlined || bordered) ? (Style.capsuleBorderWidth || 1) : 0
    implicitHeight: contentLayout.implicitHeight + padding * 2
    clip: true

    function variantColor() {
        if (variant === "surface")
            return Color.mSurface;
        if (variant === "primary")
            return Qt.alpha(accentColor, elevated ? 0.20 : 0.14);
        if (variant === "error")
            return Qt.alpha(Color.mError, elevated ? 0.20 : 0.12);
        if (variant === "transparent")
            return "transparent";
        return elevated ? Color.mSurfaceVariant : Qt.alpha(Color.mSurfaceVariant, 0.92);
    }

    ColumnLayout {
        id: contentLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.padding
        }
        spacing: root.spacing
    }
}
