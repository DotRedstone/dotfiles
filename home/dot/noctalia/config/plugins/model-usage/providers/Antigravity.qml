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

            // [Prompt credits → primary rate limit]
            if (data.promptCredits) {
                const pc = data.promptCredits;
                const used = Number(pc.usedPercent ?? 0);
                const usedPct = used <= 1 ? used * 100 : used;
                root.rateLimitPercent = Math.min(1, Math.max(0, usedPct / 100));
                root.rateLimitLabel = pluginApi?.tr("providers.antigravity.credits_label") ?? "Prompt Credits";
                root.rateLimitResetAt = "";

                quotas.push({
                    label: root.rateLimitLabel,
                    percent: root.rateLimitPercent,
                    resetAt: ""
                });
            }

            // [Models → secondary rate limit (first exhausted or highest usage)]
            const models = data.models ?? [];
            if (models.length > 0) {
                let worst = models[0];
                for (let i = 1; i < models.length; i++) {
                    if ((models[i].usedPercent ?? 0) > (worst.usedPercent ?? 0))
                        worst = models[i];
                }
                const secondaryUsed = Number(worst.usedPercent ?? 0);
                const secondaryUsedPct = secondaryUsed <= 1 ? secondaryUsed * 100 : secondaryUsed;
                root.secondaryRateLimitPercent = Math.min(1, Math.max(0, secondaryUsedPct / 100));
                root.secondaryRateLimitLabel = worst.label ?? "Model";
                root.secondaryRateLimitResetAt = worst.resetTime ?? "";

                for (let i = 0; i < models.length; i++) {
                    const m = models[i];
                    const up = Number(m.usedPercent ?? 0);
                    const upPct = up <= 1 ? up * 100 : up;
                    quotas.push({
                        label: m.label ?? "Model",
                        percent: Math.min(1, Math.max(0, upPct / 100)),
                        resetAt: m.resetTime ?? ""
                    });
                }
            }

            root.quotas = quotas;

            // [Model breakdown → modelUsage for detail section]
            if (models.length > 0) {
                const usage = {};
                for (let i = 0; i < models.length; i++) {
                    const m = models[i];
                    usage[m.label ?? ("model_" + i)] = {
                        inputTokens: m.usedPercent ?? 0,
                        outputTokens: m.remainingPercent ?? 0,
                        cacheReadInputTokens: 0,
                        cacheCreationInputTokens: 0
                    };
                }
                root.modelUsage = usage;
            }

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
}
