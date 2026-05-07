import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var options: []
    property string currentKey: ""
    signal selected(string key)

    Layout.fillWidth: true
    implicitHeight: tabBar.implicitHeight
    implicitWidth: tabBar.implicitWidth

    NTabBar {
        id: tabBar
        anchors.fill: parent

        Repeater {
            model: root.options

            NTabButton {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: modelData.label ?? ""
                checked: (modelData.key ?? "") === root.currentKey
                onClicked: root.selected(modelData.key ?? "")
            }
        }
    }
}
