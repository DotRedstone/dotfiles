import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property string providerId: "copilot"
    property string providerName: "Copilot"
    property string providerIcon: "ai"
    property bool enabled: false
    property bool ready: false

    property real rateLimitPercent: -1
    property string rateLimitLabel: "Premium"
    property string rateLimitResetAt: ""
    property real secondaryRateLimitPercent: -1
    property string secondaryRateLimitLabel: "Chat"
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
    property string authHelpText: pluginApi?.tr("providers.copilot.auth_help") ?? "Run `gh auth login` to re-authenticate."
    property bool hasLocalStats: false
    property string usageStatusText: ""

    property string ghToken: ""
    property string appsOauthToken: ""
    property double lastRefreshAtMs: 0
    property int refreshMinIntervalMs: 5 * 60 * 1000
    property var providerSettings: ({})

    function resolvePath(p) {
        if (p && p.startsWith("~"))
            return (Quickshell.env("HOME") ?? "/home") + p.substring(1);
        return p;
    }

    FileView {
        id: copilotAppsFile
        path: root.resolvePath("~/.config/github-copilot/apps.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseAppsOauthToken(text())
    }

    Process {
        id: tokenProcess
        command: ["gh", "auth", "token"]
        running: false
        stdout: StdioCollector {
            id: tokenOutput
            onStreamFinished: {
                const token = text.trim();
                if (token) {
                    root.ghToken = token;
                    root.fetchUsage();
                } else if (root.appsOauthToken) {
                    root.ghToken = root.appsOauthToken;
                    root.fetchUsage();
                } else {
                    Logger.e("model-usage/copilot", "gh auth token returned empty");
                    root.usageStatusText = pluginApi?.tr("providers.copilot.no_token") ?? "No token";
                    root.ready = false;
                    root.clearRateLimits();
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                Logger.e("model-usage/copilot", "gh auth token failed (exit " + code + ")");
                if (code === 127) {
                    if (root.appsOauthToken) {
                        root.ghToken = root.appsOauthToken;
                        root.fetchUsage();
                        return;
                    }
                    root.usageStatusText = pluginApi?.tr("providers.copilot.gh_missing") ?? "gh CLI not found";
                } else
                    root.usageStatusText = pluginApi?.tr("providers.copilot.not_auth") ?? "Not authenticated";
                root.ready = false;
                root.clearRateLimits();
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refreshToken()
    }

    onEnabledChanged: {
        if (enabled) {
            copilotAppsFile.reload();
            refreshToken();
        }
    }

    function refreshToken() {
        tokenProcess.running = true;
    }

    function parseAppsOauthToken(content) {
        try {
            const data = JSON.parse(content);
            const found = findOauthToken(data);
            if (found)
                root.appsOauthToken = found;
        } catch (e) {
            // Ignore parse failures; gh token flow remains primary.
        }
    }

    function findOauthToken(node) {
        if (!node)
            return "";
        if (typeof node === "object") {
            if (typeof node.oauth_token === "string" && node.oauth_token.length > 0)
                return node.oauth_token;
            if (Array.isArray(node)) {
                for (let i = node.length - 1; i >= 0; i--) {
                    const token = findOauthToken(node[i]);
                    if (token)
                        return token;
                }
                return "";
            }
            const keys = Object.keys(node);
            for (let i = 0; i < keys.length; i++) {
                const token = findOauthToken(node[keys[i]]);
                if (token)
                    return token;
            }
        }
        return "";
    }

    function fetchUsage() {
        if (!root.ghToken)
            return;

        const xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.github.com/copilot_internal/user");
        xhr.setRequestHeader("Authorization", "token " + root.ghToken);
        xhr.setRequestHeader("Accept", "application/json");

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status === 401 || xhr.status === 403) {
                root.usageStatusText = pluginApi?.tr("providers.copilot.token_invalid") ?? "Token invalid";
                root.ready = false;
                root.ghToken = "";
                root.tierLabel = "";
                root.clearRateLimits();
                Logger.e("model-usage/copilot", "Auth failed (status " + xhr.status + ")");
                return;
            }

            if (xhr.status < 200 || xhr.status >= 300) {
                Logger.e("model-usage/copilot", "Usage request failed (status " + xhr.status + ")");
                root.ready = false;
                root.clearRateLimits();
                return;
            }

            try {
                const data = JSON.parse(xhr.responseText);
                root.parseUsageData(data);
                root.usageStatusText = "";
                root.ready = true;
            } catch (e) {
                Logger.e("model-usage/copilot", "Failed to parse usage response:", e);
            }
        };

        xhr.send();
    }

    function parseUsageData(data) {
        root.clearRateLimits();
        root.tierLabel = data.copilot_plan ? formatPlan(data.copilot_plan) : "";

        const resetDate = data.quota_reset_date ?? "";

        // Paid tier: quota_snapshots
        const snapshots = data.quota_snapshots;
        if (snapshots) {
            const rows = [];
            const premium = snapshots.premium_interactions ?? snapshots.premium_requests;
            const premiumUsedNorm = usageNormFromSnapshot(premium);
            if (premiumUsedNorm >= 0) {
                rows.push({
                    percent: premiumUsedNorm,
                    label: "Completions / Premium",
                    resetAt: normalizeResetAt(resetDate)
                });
            }

            const chat = snapshots.chat;
            const chatUsedNorm = usageNormFromSnapshot(chat);
            if (chatUsedNorm >= 0) {
                const chatUsedPct = Math.round(chatUsedNorm * 100);
                rows.push({
                    percent: chatUsedNorm,
                    label: "Chat (" + chatUsedPct + "%)",
                    resetAt: normalizeResetAt(resetDate)
                });
            }
            root.applyQuotaRows(rows);
        }

        // Free tier: limited_user_quotas
        if (data.limited_user_quotas && data.monthly_quotas) {
            const lq = data.limited_user_quotas;
            const mq = data.monthly_quotas;
            const freeReset = data.limited_user_reset_date ?? "";
            let chatRow = null;
            let completionsRow = null;

            if (typeof lq.chat === "number" && typeof mq.chat === "number" && mq.chat > 0) {
                const used = mq.chat - lq.chat;
                const usedPct = Math.min(100, Math.max(0, Math.round((used / mq.chat) * 100)));
                chatRow = {
                    percent: usedPct / 100,
                    label: "Chat (" + used + "/" + mq.chat + ")",
                    resetAt: normalizeResetAt(freeReset)
                };
            }

            if (typeof lq.completions === "number" && typeof mq.completions === "number" && mq.completions > 0) {
                const used = mq.completions - lq.completions;
                const usedPct = Math.min(100, Math.max(0, Math.round((used / mq.completions) * 100)));
                completionsRow = {
                    percent: usedPct / 100,
                    label: "Completions (" + used + "/" + mq.completions + ")",
                    resetAt: normalizeResetAt(freeReset)
                };
            }

            const rows = [];
            if (completionsRow)
                rows.push(completionsRow);
            if (chatRow)
                rows.push(chatRow);
            root.applyQuotaRows(rows);
        }
    }

    function applyQuotaRows(rows) {
        root.quotas = rows;
        const first = rows[0] ?? null;
        const second = rows[1] ?? null;
        root.rateLimitPercent = first ? first.percent : -1;
        root.rateLimitLabel = first ? first.label : "Completions";
        root.rateLimitResetAt = first ? first.resetAt : "";
        root.secondaryRateLimitPercent = second ? second.percent : -1;
        root.secondaryRateLimitLabel = second ? second.label : "Chat";
        root.secondaryRateLimitResetAt = second ? second.resetAt : "";
    }

    function formatPlan(plan) {
        if (!plan)
            return "";
        const p = String(plan);
        return p.charAt(0).toUpperCase() + p.slice(1);
    }

    function toNumber(v, fallback) {
        if (fallback === undefined)
            fallback = -1;
        const n = Number(v);
        return isNaN(n) ? fallback : n;
    }

    function usageNormFromSnapshot(snapshot) {
        if (!snapshot)
            return -1;

        // GitHub may return remaining percent in either 0~100 or 0~1 form.
        const pr = toNumber(snapshot.percent_remaining, -1);
        if (pr >= 0) {
            const remainingPct = pr <= 1 ? pr * 100 : pr;
            const usedPct = Math.min(100, Math.max(0, 100 - remainingPct));
            return usedPct / 100;
        }

        // Fallback to counters if percent_remaining is unavailable.
        const entitlement = toNumber(snapshot.entitlement, -1);
        const remaining = toNumber(snapshot.remaining, -1);
        if (entitlement > 0 && remaining >= 0)
            return Math.min(1, Math.max(0, (entitlement - remaining) / entitlement));

        const quotaEntitled = toNumber(snapshot.quota_entitled, -1);
        const quotaRemaining = toNumber(snapshot.quota_remaining, -1);
        if (quotaEntitled > 0 && quotaRemaining >= 0)
            return Math.min(1, Math.max(0, (quotaEntitled - quotaRemaining) / quotaEntitled));

        return -1;
    }

    function clearRateLimits() {
        root.rateLimitPercent = -1;
        root.rateLimitLabel = "Premium";
        root.rateLimitResetAt = "";
        root.secondaryRateLimitPercent = -1;
        root.secondaryRateLimitLabel = "Chat";
        root.secondaryRateLimitResetAt = "";
        root.quotas = [];
    }

    function normalizeResetAt(value) {
        if (value === null || value === undefined || value === "")
            return "";
        const d = new Date(String(value));
        if (!isNaN(d.getTime()))
            return d.toISOString();
        return "";
    }

    function refresh() {
        const now = Date.now();
        if (root.lastRefreshAtMs > 0 && (now - root.lastRefreshAtMs) < root.refreshMinIntervalMs)
            return;
        root.lastRefreshAtMs = now;
        refreshToken();
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
