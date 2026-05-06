import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property string providerId: "codex"
    property string providerName: "Codex"
    property string providerIcon: "ai"
    property bool enabled: false
    property bool ready: false
    property string usageStatusText: ""

    property real rateLimitPercent: -1
    property string rateLimitLabel: pluginApi?.tr("providers.codex.7d_window") ?? "Weekly (7-day)"
    property string rateLimitResetAt: ""
    property real secondaryRateLimitPercent: -1
    property string secondaryRateLimitLabel: ""
    property string secondaryRateLimitResetAt: ""

    property int todayPrompts: 0
    property int todaySessions: 0
    property int todayTotalTokens: 0
    property var todayTokensByModel: ({})

    property var recentDays: []
    property int totalPrompts: 0
    property int totalSessions: 0
    property var modelUsage: ({})
    property var quotas: []

    property string tierLabel: ""
    property string authHelpText: pluginApi?.tr("providers.codex.auth_help") ?? "Run `codex` to authenticate."
    property bool hasLocalStats: true

    property string configModel: ""
    property var providerSettings: ({})
    property bool hasCachedUsage: false

    function resolvePath(p) {
        if (p && p.startsWith("~"))
            return (Quickshell.env("HOME") ?? "/home") + p.substring(1);
        return p;
    }

    FileView {
        id: usageFile
        path: root.resolvePath("~/.cache/noctalia/model-usage/codex.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseUsage(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Logger.e("model-usage/codex", "codex.json not found");
        }
    }

    FileView {
        id: configFile
        path: root.resolvePath("~/.codex/config.toml")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseConfig(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Logger.e("model-usage/codex", "config.toml not found");
        }
    }

    FileView {
        id: authFile
        path: root.resolvePath("~/.codex/auth.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseAuth(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Logger.e("model-usage/codex", "auth.json not found");
        }
    }

    Process {
        id: collectorProcess
        command: ["codex-usage-json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text)
                    root.parseUsage(text);
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                if (!root.hasCachedUsage)
                    root.ready = false;
                root.usageStatusText = "codex-usage-json exited with code " + code;
                Logger.e("model-usage/codex", root.usageStatusText);
            }
        }
    }

    Timer {
        interval: 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    onEnabledChanged: {
        if (enabled)
            refresh();
    }

    function parseUsage(content) {
        try {
            const data = JSON.parse(content);
            if (data.ok === false) {
                const err = data.error ?? "fetch failed";
                root.usageStatusText = root.hasCachedUsage ? err + " (showing cached data)" : err;
                root.ready = root.hasCachedUsage;
                return;
            }

            root.usageStatusText = "";
            root.todayPrompts = data.todayPrompts ?? 0;
            root.todaySessions = data.todaySessions ?? 0;
            root.todayTotalTokens = data.todayTotalTokens ?? 0;
            root.todayTokensByModel = data.todayTokensByModel ?? {};
            root.recentDays = data.recentDays ?? [];
            root.totalPrompts = data.totalPrompts ?? 0;
            root.totalSessions = data.totalSessions ?? 0;
            root.modelUsage = data.modelUsage ?? {};
            root.quotas = data.quotas ?? [];

            root.rateLimitPercent = data.rateLimitPercent ?? -1;
            root.rateLimitLabel = localizeRateLimitLabel(data.rateLimitLabel ?? "");
            root.rateLimitResetAt = data.rateLimitResetAt ?? "";
            root.secondaryRateLimitPercent = data.secondaryRateLimitPercent ?? -1;
            root.secondaryRateLimitLabel = localizeRateLimitLabel(data.secondaryRateLimitLabel ?? "");
            root.secondaryRateLimitResetAt = data.secondaryRateLimitResetAt ?? "";

            root.quotas = root.quotas.map(q => ({
                label: localizeRateLimitLabel(q.label ?? ""),
                percent: q.percent ?? -1,
                resetAt: q.resetAt ?? ""
            }));

            root.ready = true;
            root.hasCachedUsage = true;
        } catch (e) {
            Logger.e("model-usage/codex", "Failed to parse codex usage:", e);
            if (!root.hasCachedUsage)
                root.ready = false;
        }
    }

    function parseConfig(content) {
        try {
            const match = content.match(/model\s*=\s*"([^"]+)"/);
            if (match)
                root.configModel = match[1];
        } catch (e) {
            Logger.e("model-usage/codex", "Failed to parse config.toml:", e);
        }
    }

    function parseAuth(content) {
        try {
            const data = JSON.parse(content);
            if (data.auth_mode)
                root.tierLabel = data.auth_mode;
        } catch (e) {
            Logger.e("model-usage/codex", "Failed to parse auth.json:", e);
        }
    }

    function refresh() {
        usageFile.reload();
        configFile.reload();
        authFile.reload();
        collectorProcess.running = true;
    }

    function localizeRateLimitLabel(label) {
        if (label === "5h window")
            return "5 小时使用限额";
        if (label === "7d window")
            return "每周使用限额";
        if (label.endsWith("h window"))
            return label.replace("h window", pluginApi?.tr("providers.codex.h_window") ?? "h window");
        return label;
    }

    function formatQuotaResetText(quota) {
        const isoTimestamp = quota?.resetAt ?? "";
        if (!isoTimestamp)
            return "";
        const reset = new Date(isoTimestamp);
        if (Number.isNaN(reset.getTime()))
            return "";

        const label = quota?.label ?? "";
        const hh = String(reset.getHours()).padStart(2, "0");
        const mm = String(reset.getMinutes()).padStart(2, "0");
        if (label === "每周使用限额") {
            return "重置时间：" + reset.getFullYear() + "年" + (reset.getMonth() + 1) + "月" + reset.getDate() + "日 " + hh + ":" + mm;
        }
        return "重置时间：" + hh + ":" + mm;
    }

    function formatResetTime(isoTimestamp) {
        if (!isoTimestamp)
            return "";
        const reset = new Date(isoTimestamp);
        const now = new Date();
        const diffMs = reset.getTime() - now.getTime();
        if (diffMs <= 0)
            return pluginApi?.tr("providers.common.now") ?? "now";
        const hours = Math.floor(diffMs / 3600000);
        const mins = Math.floor((diffMs % 3600000) / 60000);
        if (hours > 24)
            return Math.floor(hours / 24) + "d " + (hours % 24) + "h";
        if (hours > 0)
            return hours + "h " + mins + "m";
        return mins + "m";
    }
}
