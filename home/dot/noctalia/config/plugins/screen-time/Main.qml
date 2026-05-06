import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property var pluginApi: null
    property var pluginSettings: pluginApi?.pluginSettings ?? pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

    property int refreshIntervalSec: pluginSettings?.refreshIntervalSec ?? 60
    property int topAppLimit: pluginSettings?.topAppLimit ?? 5
    property bool showCurrentApp: pluginSettings?.showCurrentApp ?? true
    property string barDisplayMode: pluginSettings?.barDisplayMode ?? "duration"

    property bool ready: false
    property bool ok: false
    property string sourceStatusText: pluginApi?.tr("status.waiting") ?? "Waiting for ActivityWatch"
    property string watcher: "awatcher"
    property string fetchedAt: ""
    property int todayTotalSeconds: 0
    property int weekTotalSeconds: 0
    property int monthTotalSeconds: 0
    property int afkSeconds: 0
    property int weekAfkSeconds: 0
    property int monthAfkSeconds: 0
    property string currentApp: ""
    property var topApps: []
    property var weekTopApps: []
    property var monthTopApps: []
    property var dailyTotals: []

    function resolvePath(p) {
        if (p && p.startsWith("~"))
            return (Quickshell.env("HOME") ?? "/home") + p.substring(1);
        return p;
    }

    FileView {
        id: summaryFile
        path: root.resolvePath("~/.cache/noctalia/screen-time/summary.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseSummary(text())
        onLoadFailed: error => {
            root.ready = false;
            root.ok = false;
            root.sourceStatusText = pluginApi?.tr("status.no_cache") ?? "No screen-time summary yet";
        }
    }

    Process {
        id: collectorProcess
        command: ["screen-time-json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text)
                    root.parseSummary(text);
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.ready = false;
                root.ok = false;
                root.sourceStatusText = pluginApi?.tr("status.helper_failed") ?? "Screen-time helper failed";
            }
        }
    }

    Timer {
        interval: Math.max(5, root.refreshIntervalSec) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        summaryFile.reload();
        if (!collectorProcess.running)
            collectorProcess.running = true;
    }

    function parseSummary(content) {
        try {
            const data = JSON.parse(content);
            root.ok = data.ok === true;
            root.ready = true;
            root.watcher = data.watcher ?? "awatcher";
            root.fetchedAt = data.fetchedAt ?? "";
            root.todayTotalSeconds = Number(data.todayTotalSeconds ?? 0);
            root.weekTotalSeconds = Number(data.weekTotalSeconds ?? 0);
            root.monthTotalSeconds = Number(data.monthTotalSeconds ?? 0);
            root.afkSeconds = Number(data.afkSeconds ?? 0);
            root.weekAfkSeconds = Number(data.weekAfkSeconds ?? 0);
            root.monthAfkSeconds = Number(data.monthAfkSeconds ?? 0);
            root.currentApp = String(data.currentApp ?? "");
            root.topApps = Array.isArray(data.topApps) ? data.topApps : [];
            root.weekTopApps = Array.isArray(data.weekTopApps) ? data.weekTopApps : [];
            root.monthTopApps = Array.isArray(data.monthTopApps) ? data.monthTopApps : [];
            root.dailyTotals = Array.isArray(data.dailyTotals) ? data.dailyTotals : [];
            root.sourceStatusText = root.ok ? (pluginApi?.tr("status.connected") ?? "ActivityWatch connected") : (data.error ?? (pluginApi?.tr("status.unavailable") ?? "ActivityWatch unavailable"));
        } catch (_) {
            root.ready = false;
            root.ok = false;
            root.sourceStatusText = pluginApi?.tr("status.parse_failed") ?? "Screen-time summary parse failed";
        }
    }

    function visibleTopApps() {
        const items = Array.isArray(topApps) ? topApps : [];
        return items.slice(0, Math.max(1, topAppLimit));
    }

    function visibleWeekTopApps() {
        const items = Array.isArray(weekTopApps) ? weekTopApps : [];
        return items.slice(0, Math.max(1, topAppLimit));
    }

    function topAppMaxSeconds() {
        const items = visibleTopApps();
        if (items.length === 0)
            return 1;
        return Math.max(1, Number(items[0].seconds || 0));
    }

    function topAppShare(seconds) {
        return Math.max(0.04, Math.min(1, Number(seconds || 0) / topAppMaxSeconds()));
    }

    function maxDailySeconds() {
        const items = Array.isArray(dailyTotals) ? dailyTotals : [];
        if (items.length === 0)
            return 1;
        let max = 1;
        for (const item of items)
            max = Math.max(max, Number(item.seconds || 0));
        return max;
    }

    function dailyShare(seconds) {
        return Math.max(0.04, Math.min(1, Number(seconds || 0) / maxDailySeconds()));
    }

    function formatDuration(seconds) {
        const total = Math.max(0, Number(seconds || 0));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (hours > 0)
            return hours + "h " + String(minutes).padStart(2, "0") + "m";
        return minutes + "m";
    }

    function formatTimestamp(value) {
        if (!value)
            return pluginApi?.tr("general.never") ?? "Never";
        const d = new Date(value);
        if (Number.isNaN(d.getTime()))
            return pluginApi?.tr("general.unknown") ?? "Unknown";
        return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0") + ":" + String(d.getSeconds()).padStart(2, "0");
    }

    function shortAppName(name, maxLen) {
        const value = String(name || "");
        if (value.length <= maxLen)
            return value;
        return value.substring(0, Math.max(1, maxLen - 1)) + "...";
    }

    function appInitial(name) {
        const value = String(name || "?").trim();
        if (value === "")
            return "?";
        return value.charAt(0).toUpperCase();
    }
}
