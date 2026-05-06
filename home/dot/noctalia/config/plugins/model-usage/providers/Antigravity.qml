import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property string providerId: "antigravity"
    property string providerName: "Antigravity"
    property string providerIcon: "ai"
    property bool enabled: false
    property bool ready: false
    property string usageStatusText: ""

    property real rateLimitPercent: -1
    property string rateLimitLabel: pluginApi?.tr("providers.antigravity.credits_label") ?? "Prompt Credits"
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

    property string tierLabel: "Antigravity"
    property string authHelpText: pluginApi?.tr("providers.antigravity.auth_help") ?? "Data from antigravity-usage-json"
    property bool hasLocalStats: false

    property var providerSettings: ({})
    property bool hasCachedUsage: false

    function resolvePath(p) {
        if (p && p.startsWith("~"))
            return (Quickshell.env("HOME") ?? "/home") + p.substring(1);
        return p;
    }

    // [Cache file]
    FileView {
        id: statsFile
        path: root.resolvePath("~/.cache/noctalia/model-usage/antigravity.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseStats(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Logger.e("model-usage/antigravity", "antigravity.json not found");
        }
    }

    // [Collector process]
    Process {
        id: collectorProcess
        command: ["antigravity-usage-json"]
        running: false
        stdout: StdioCollector {
            id: collectorOutput
            onStreamFinished: {
                // Cache written by script; FileView will pick it up.
                // Parse stdout as fallback in case FileView is slow.
                if (text)
                    root.parseStats(text);
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                Logger.e("model-usage/antigravity", "antigravity-usage-json exited with code " + code);
        }
    }

    onEnabledChanged: {
        if (enabled)
            statsFile.reload();
    }

    function parseStats(content) {
        try {
            const data = JSON.parse(content);

            if (data.ok === false) {
                const err = data.error ?? "fetch failed";
                if (root.hasCachedUsage)
                    root.usageStatusText = err + " (showing cached data)";
                else
                    root.usageStatusText = err;
                return;
            }

            root.usageStatusText = "";

            const quotas = [];

            // Prompt credits from current antigravity-usage output do not match
            // the app's "Available AI Credits" semantics. Hide this summary until
            // upstream exposes authoritative AI credits fields.
            root.rateLimitPercent = -1;
            root.rateLimitLabel = pluginApi?.tr("providers.antigravity.credits_label") ?? "Prompt Credits";
            root.rateLimitResetAt = "";

            // [Models → secondary rate limit (first exhausted or highest usage)]
            const models = data.models ?? [];
            const sortedModels = models.slice().sort((a, b) => modelSortRank(a?.label ?? "") - modelSortRank(b?.label ?? ""));
            if (models.length > 0) {
                let worst = null;
                let worstUsed = -1;
                for (let i = 0; i < models.length; i++) {
                    const used = normalizeModelPercent(models[i].usedPercent);
                    if (used >= 0 && used > worstUsed) {
                        worst = models[i];
                        worstUsed = used;
                    }
                }
                if (worst) {
                    root.rateLimitPercent = worstUsed;
                    root.rateLimitLabel = worst.label ?? "Model";
                    root.rateLimitResetAt = worst.resetTime ?? "";
                    root.secondaryRateLimitPercent = worstUsed;
                    root.secondaryRateLimitLabel = worst.label ?? "Model";
                    root.secondaryRateLimitResetAt = worst.resetTime ?? "";
                }

                for (let i = 0; i < sortedModels.length; i++) {
                    const m = sortedModels[i];
                    const up = normalizeModelPercent(m.usedPercent);
                    quotas.push({
                        label: m.label ?? "Model",
                        percent: up,
                        resetAt: m.resetTime ?? ""
                    });
                }
            }

            root.quotas = quotas;

            // antigravity-usage currently exposes quota percentages, not true token
            // counters. Keep token breakdown empty to avoid misleading values.
            root.modelUsage = {};

            root.ready = true;
            root.hasCachedUsage = true;
        } catch (e) {
            Logger.e("model-usage/antigravity", "Failed to parse antigravity.json:", e);
        }
    }

    function refresh() {
        statsFile.reload();
        collectorProcess.running = true;
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

    function normalizeModelPercent(value) {
        if (value === null || value === undefined)
            return -1;
        const n = Number(value);
        if (!(n >= 0))
            return -1;
        return Math.min(1, Math.max(0, n <= 1 ? n : n / 100));
    }

    function modelSortRank(label) {
        const t = String(label).toLowerCase();
        if (t.indexOf("gemini 3 flash") !== -1)
            return 10;
        if (t.indexOf("gemini 3.1 pro (low)") !== -1)
            return 20;
        if (t.indexOf("gemini 3.1 pro (high)") !== -1)
            return 30;
        if (t.indexOf("claude opus") !== -1)
            return 40;
        if (t.indexOf("claude sonnet") !== -1)
            return 50;
        if (t.indexOf("gpt-oss") !== -1)
            return 60;
        return 999;
    }
}
