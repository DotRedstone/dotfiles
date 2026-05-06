import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
    property var cfg: pluginApi?.pluginSettings ?? defaults

    property int refreshIntervalSec: cfg.refreshIntervalSec ?? defaults.refreshIntervalSec ?? 60
    property int topAppLimit: cfg.topAppLimit ?? defaults.topAppLimit ?? 5
    property bool showCurrentApp: cfg.showCurrentApp ?? defaults.showCurrentApp ?? true
    property string barDisplayMode: cfg.barDisplayMode ?? defaults.barDisplayMode ?? "duration"

    spacing: Style.marginL

    NText {
        text: pluginApi?.tr("settings.title") ?? "Screen Time Settings"
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NText {
                text: pluginApi?.tr("settings.refresh_interval") ?? "Refresh interval (seconds)"
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightSemiBold
                color: Color.mOnSurface
            }
            NText {
                text: pluginApi?.tr("settings.refresh_interval_desc") ?? "How often the helper refreshes the local summary cache."
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
            }
            NSpinBox {
                from: 15
                to: 600
                value: root.refreshIntervalSec
                stepSize: 15
                onValueChanged: root.refreshIntervalSec = value
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NText {
                text: pluginApi?.tr("settings.top_limit") ?? "Top app count"
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightSemiBold
                color: Color.mOnSurface
            }
            NText {
                text: pluginApi?.tr("settings.top_limit_desc") ?? "Number of app-level rows to show in the panel."
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
            }
            NSpinBox {
                from: 3
                to: 20
                value: root.topAppLimit
                stepSize: 1
                onValueChanged: root.topAppLimit = value
            }
        }

        NToggle {
            label: pluginApi?.tr("settings.show_current_app") ?? "Show current app"
            description: pluginApi?.tr("settings.show_current_app_desc") ?? "Allow the bar and panel to show the current app id/name."
            checked: root.showCurrentApp
            onToggled: checked => root.showCurrentApp = checked
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NText {
                text: pluginApi?.tr("settings.bar_mode") ?? "Bar display"
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightSemiBold
                color: Color.mOnSurface
            }
            NComboBox {
                Layout.fillWidth: true
                model: [
                    { key: "duration", name: pluginApi?.tr("settings.bar_mode_duration") ?? "Today duration" },
                    { key: "current", name: pluginApi?.tr("settings.bar_mode_current") ?? "Current app" }
                ]
                currentKey: root.barDisplayMode
                onSelected: key => root.barDisplayMode = key
            }
        }
    }

    function saveSettings() {
        if (!pluginApi)
            return;
        pluginApi.pluginSettings.refreshIntervalSec = root.refreshIntervalSec;
        pluginApi.pluginSettings.topAppLimit = root.topAppLimit;
        pluginApi.pluginSettings.showCurrentApp = root.showCurrentApp;
        pluginApi.pluginSettings.barDisplayMode = root.barDisplayMode;
        pluginApi.saveSettings();
    }
}
