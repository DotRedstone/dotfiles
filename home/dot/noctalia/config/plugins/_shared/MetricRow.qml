import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string subtitle: ""
    property string icon: ""
    property string leadingText: ""
    property real progress: -1
    property color accentColor: Color.mPrimary
    property color rowColor: Qt.alpha(Color.mSurface, 0.58)
    property bool showBackground: true

    Layout.fillWidth: true
    radius: Style.radiusS
    color: showBackground ? rowColor : "transparent"
    implicitHeight: rowColumn.implicitHeight + (showBackground ? Style.marginM * 2 : 0)

    ColumnLayout {
        id: rowColumn
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: root.showBackground ? Style.marginM : 0
        }
        spacing: Style.marginXS

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            Rectangle {
                visible: root.icon !== "" || root.leadingText !== ""
                width: 34 * Style.uiScaleRatio
                height: width
                radius: Style.radiusS
                color: Qt.alpha(root.accentColor, 0.12)

                NIcon {
                    visible: root.icon !== ""
                    anchors.centerIn: parent
                    icon: root.icon
                    pointSize: Style.fontSizeM
                    color: root.accentColor
                }

                NText {
                    visible: root.icon === ""
                    anchors.centerIn: parent
                    text: root.leadingText
                    pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightBold
                    color: root.accentColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXXS

                NText {
                    text: root.label
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                NText {
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            NText {
                text: root.value
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                elide: Text.ElideRight
            }
        }

        ProgressBar {
            visible: root.progress >= 0
            value: root.progress
            fillColor: root.accentColor
        }
    }
}
