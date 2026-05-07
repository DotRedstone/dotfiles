import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    property var options: []
    property string currentKey: ""
    signal selected(string key)

    Layout.fillWidth: true
    radius: Style.radiusS
    color: Color.mSurfaceVariant
    implicitHeight: segmentRow.implicitHeight + Style.marginM * 2

    RowLayout {
        id: segmentRow
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Style.marginM
        }
        spacing: Style.marginS

        Repeater {
            model: root.options

            Rectangle {
                required property var modelData
                readonly property bool active: (modelData.key ?? "") === root.currentKey

                Layout.fillWidth: true
                radius: Style.radiusS
                color: active ? Color.mPrimary : "transparent"
                implicitHeight: segmentText.implicitHeight + Style.marginM

                NText {
                    id: segmentText
                    anchors.centerIn: parent
                    text: modelData.label ?? ""
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: parent.active ? Color.mOnPrimary : Color.mOnSurfaceVariant
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(parent.modelData.key ?? "")
                }
            }
        }
    }
}
