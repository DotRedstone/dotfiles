import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var options: []
    property var model: []
    property string currentKey: ""
    property int currentIndex: -1
    signal selected(string key)
    signal clicked(int index)

    Layout.fillWidth: true
    implicitHeight: tabBar.implicitHeight
    implicitWidth: tabBar.implicitWidth

    NTabBar {
        id: tabBar
        anchors.fill: parent

        Repeater {
            model: root.options.length > 0 ? root.options : root.model

            NTabButton {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: root.optionLabel(modelData)
                checked: root.currentKey !== "" ? root.optionKey(modelData, index) === root.currentKey : index === root.currentIndex
                onClicked: {
                    root.selected(root.optionKey(modelData, index));
                    root.clicked(index);
                }
            }
        }
    }

    function optionLabel(option) {
        if (typeof option === "string")
            return option;
        return option.label ?? option.name ?? "";
    }

    function optionKey(option, index) {
        if (typeof option === "string")
            return String(index);
        return option.key ?? String(index);
    }
}
