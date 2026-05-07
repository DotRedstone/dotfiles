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

    property string mode: "day"
    property string range: "calendar"
    property bool ready: false
    property bool ok: false
    property string sourceStatusText: pluginApi?.tr("status.waiting") ?? "Waiting for ActivityWatch"
    property string title: pluginApi?.tr("title.day_calendar") ?? "今日屏幕使用时长"
    property string primaryLabel: "0分钟"
    property string comparisonLabel: ""
    property int totalSeconds: 0
    property int todayTotalSeconds: totalSeconds
    property int averageSeconds: 0
    property int afkSeconds: 0
    property string currentApp: ""
    property var chart: []
    property var apps: []
    property string appListTitle: pluginApi?.tr("apps.day_calendar") ?? "今日应用使用情况"
    property string lastUpdated: ""

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
        command: ["screen-time-json", "--mode", root.mode, "--range", root.range, "--top", String(root.topAppLimit)]
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

    function setMode(nextMode) {
        if (!["day", "week", "month"].includes(nextMode) || root.mode === nextMode)
            return;
        root.mode = nextMode;
        root.refresh();
    }

    function setRange(nextRange) {
        if (!["calendar", "rolling"].includes(nextRange) || root.range === nextRange)
            return;
        root.range = nextRange;
        root.refresh();
    }

    function toggleRange() {
        setRange(root.range === "calendar" ? "rolling" : "calendar");
    }

    function parseSummary(content) {
        try {
            const data = JSON.parse(content);
            if ((data.mode ?? root.mode) !== root.mode || (data.range ?? root.range) !== root.range)
                return;
            root.ok = data.ok === true;
            root.ready = true;
            root.title = data.title ?? root.fallbackTitle();
            root.primaryLabel = data.primaryLabel ?? "0分钟";
            root.comparisonLabel = data.comparisonLabel ?? "";
            root.totalSeconds = Number(data.totalSeconds ?? 0);
            root.averageSeconds = Number(data.averageSeconds ?? 0);
            root.afkSeconds = Number(data.afkSeconds ?? 0);
            root.currentApp = String(data.currentApp ?? "");
            root.chart = Array.isArray(data.chart) ? data.chart : [];
            root.apps = Array.isArray(data.apps) ? data.apps : [];
            root.appListTitle = data.appListTitle ?? root.fallbackAppListTitle();
            root.lastUpdated = data.lastUpdated ?? data.fetchedAt ?? "";
            root.sourceStatusText = root.ok ? (pluginApi?.tr("status.connected") ?? "ActivityWatch connected") : (data.error ?? (pluginApi?.tr("status.unavailable") ?? "ActivityWatch unavailable"));
        } catch (_) {
            root.ready = false;
            root.ok = false;
            root.sourceStatusText = pluginApi?.tr("status.parse_failed") ?? "Screen-time summary parse failed";
        }
    }

    function fallbackTitle() {
        return pluginApi?.tr("title." + root.mode + "_" + root.range) ?? "屏幕使用时长";
    }

    function fallbackAppListTitle() {
        return pluginApi?.tr("apps." + root.mode + "_" + root.range) ?? "应用使用情况";
    }

    function modeLabel(value) {
        if (value === "day")
            return pluginApi?.tr("mode.day") ?? "日";
        if (value === "week")
            return pluginApi?.tr("mode.week") ?? "周";
        return pluginApi?.tr("mode.month") ?? "月";
    }

    function rangeLabel(value) {
        if (root.mode === "day")
            return value === "calendar" ? (pluginApi?.tr("range.today") ?? "今日") : (pluginApi?.tr("range.last24") ?? "近24小时");
        if (root.mode === "week")
            return value === "calendar" ? (pluginApi?.tr("range.thisWeek") ?? "本周") : (pluginApi?.tr("range.last7") ?? "近7天");
        return value === "calendar" ? (pluginApi?.tr("range.thisMonth") ?? "本月") : (pluginApi?.tr("range.last30") ?? "近30天");
    }

    function visibleApps() {
        const items = Array.isArray(apps) ? apps : [];
        return items.slice(0, Math.max(1, topAppLimit));
    }

    function appMaxSeconds() {
        const items = visibleApps();
        if (items.length === 0)
            return 1;
        return Math.max(1, Number(items[0].seconds || 0));
    }

    function appShare(seconds) {
        return Math.max(0.04, Math.min(1, Number(seconds || 0) / appMaxSeconds()));
    }

    function maxChartSeconds() {
        const items = Array.isArray(chart) ? chart : [];
        if (items.length === 0)
            return 1;
        let max = 1;
        for (const item of items)
            max = Math.max(max, Number(item.seconds || 0));
        return max;
    }

    function chartShare(seconds) {
        return Math.max(0.04, Math.min(1, Number(seconds || 0) / maxChartSeconds()));
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
