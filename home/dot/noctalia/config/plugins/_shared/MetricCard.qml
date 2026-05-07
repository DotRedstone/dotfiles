import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

PluginCard {
    id: root

    property string label: ""
    property string value: ""
    property string subtext: ""
    property string icon: ""
    property color accentColor: Color.mPrimary

    padding: Style.marginM
    spacing: Style.marginXS
    variant: "surface"
    outlined: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NBox {
            visible: root.icon !== ""
            width: 32 * Style.uiScaleRatio
            height: width
            radius: Style.radiusS
            color: Qt.alpha(root.accentColor, 0.12)

            NIcon {
                anchors.centerIn: parent
                icon: root.icon
                pointSize: Style.fontSizeM
                color: root.accentColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
                text: root.label
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            NText {
                text: root.value
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            NText {
                visible: root.subtext !== ""
                text: root.subtext
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
