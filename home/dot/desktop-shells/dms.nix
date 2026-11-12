# ---
# Module: DMS 2 Shell
# Description: Package Dux Modular Shell (DMS 2) and declare default desktop user service
# Scope: Home Manager
# ---
# Notes:
# - Enabled by default via Install.WantedBy for graphical-session.target.
# - Switch between shells at runtime via `desktop-shell <dms|noctalia|clavis>`.

{ pkgs, lib, config, ... }:
let
  noctaliaAssets = "${config.programs.noctalia.package}/share/noctalia/assets";
  homeDir = config.home.homeDirectory;

  weztermNoctaliaTemplate = pkgs.writeText "wezterm-noctalia.toml.template" ''
    [colors]
    ansi = [
        "{{dank16term.color0.default.hex}}",
        "{{dank16term.color1.default.hex}}",
        "{{dank16term.color2.default.hex}}",
        "{{dank16term.color3.default.hex}}",
        "{{dank16term.color4.default.hex}}",
        "{{dank16term.color5.default.hex}}",
        "{{dank16term.color6.default.hex}}",
        "{{dank16term.color7.default.hex}}",
    ]
    background = "{{colors.background.default.hex}}"
    brights = [
        "{{dank16term.color8.default.hex}}",
        "{{dank16term.color9.default.hex}}",
        "{{dank16term.color10.default.hex}}",
        "{{dank16term.color11.default.hex}}",
        "{{dank16term.color12.default.hex}}",
        "{{dank16term.color13.default.hex}}",
        "{{dank16term.color14.default.hex}}",
        "{{dank16term.color15.default.hex}}",
    ]
    compose_cursor = "{{colors.primary.default.hex}}"
    cursor_bg = "{{colors.primary.default.hex}}"
    cursor_border = "{{colors.primary.default.hex}}"
    cursor_fg = "{{colors.on_primary.default.hex}}"
    foreground = "{{colors.on_surface.default.hex}}"
    scrollbar_thumb = "{{colors.primary_container.default.hex}}"
    selection_bg = "{{colors.primary_container.default.hex}}"
    selection_fg = "{{colors.on_primary_container.default.hex}}"
    split = "{{colors.outline_variant.default.hex}}"
    visual_bell = "{{colors.surface_variant.default.hex}}"

    [colors.indexed]
    16 = "{{colors.secondary.default.hex}}"
    17 = "{{colors.primary.default.hex}}"

    [colors.tab_bar]
    background = "{{colors.surface_container_lowest.default.hex}}"
    inactive_tab_edge = "{{colors.surface_variant.default.hex}}"

    [colors.tab_bar.active_tab]
    bg_color = "{{colors.primary.default.hex}}"
    fg_color = "{{colors.on_primary.default.hex}}"
    intensity = "Normal"
    italic = false
    strikethrough = false
    underline = "None"

    [colors.tab_bar.inactive_tab]
    bg_color = "{{colors.surface_container.default.hex}}"
    fg_color = "{{colors.on_surface.default.hex}}"
    intensity = "Normal"
    italic = false
    strikethrough = false
    underline = "None"

    [colors.tab_bar.inactive_tab_hover]
    bg_color = "{{colors.surface_container_high.default.hex}}"
    fg_color = "{{colors.on_surface.default.hex}}"
    intensity = "Normal"
    italic = false
    strikethrough = false
    underline = "None"

    [colors.tab_bar.new_tab]
    bg_color = "{{colors.surface_variant.default.hex}}"
    fg_color = "{{colors.on_surface.default.hex}}"
    intensity = "Normal"
    italic = false
    strikethrough = false
    underline = "None"

    [colors.tab_bar.new_tab_hover]
    bg_color = "{{colors.outline_variant.default.hex}}"
    fg_color = "{{colors.on_surface.default.hex}}"
    intensity = "Normal"
    italic = false
    strikethrough = false
    underline = "None"

    [metadata]
    author = "Noctalia"
    name = "Noctalia"
  '';

  dmsObsidianSync = pkgs.writeShellScript "dms-obsidian-sync" ''
    set -eu
    bash "${homeDir}/.local/state/noctalia/community-templates/obsidian/apply.sh" output 2>/dev/null | while IFS= read -r dst; do
      if [ -n "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -f "${homeDir}/.cache/noctalia/obsidian-snippet.css" "$dst" || true
      fi
    done
  '';

  dmsPrepareCommunityTemplates = pkgs.writeShellScript "dms-prepare-community-templates" ''
    set -eu
    mkdir -p "${homeDir}/.cache/dms/templates"
    if [ -f "${homeDir}/.local/state/noctalia/community-templates/yazi/yazi.toml" ]; then
      ${pkgs.gnused}/bin/sed 's/{{{/[fold-start]/g; s/}}}/[fold-end]/g' \
        "${homeDir}/.local/state/noctalia/community-templates/yazi/yazi.toml" \
        > "${homeDir}/.cache/dms/templates/yazi.toml"
    fi
    if [ -f "${homeDir}/.local/state/noctalia/community-templates/obsidian/obsidian.css" ]; then
      ${pkgs.gnused}/bin/sed -E \
        -e 's/\| set_alpha:? /| set_alpha: /g' \
        -e 's/ \| (lighten|darken):? [0-9.]+//g' \
        -e 's/\{\{colors\.([a-z0-9_]+)\.(default|light|dark)\.rgb_csv\}\}/{{colors.\1.\2.red}}, {{colors.\1.\2.green}}, {{colors.\1.\2.blue}}/g' \
        "${homeDir}/.local/state/noctalia/community-templates/obsidian/obsidian.css" \
        > "${homeDir}/.cache/dms/templates/obsidian.css"
    fi
    mkdir -p "${homeDir}/.config/niri/dms"
    touch "${homeDir}/.config/niri/dms/wpblur.kdl" "${homeDir}/.config/niri/dms/windowrules.kdl"
    if [ ! -s "${homeDir}/.config/niri/dms/binds.kdl" ] || ! ${pkgs.gnugrep}/bin/grep -q 'spawn "dms"' "${homeDir}/.config/niri/dms/binds.kdl" 2>/dev/null; then
      cat > "${homeDir}/.config/niri/dms/binds.kdl" << 'EOF'
binds {
    Mod+B hotkey-overlay-title="剪贴板" { spawn "dms" "ipc" "call" "clipboardPlus" "toggle"; }
    Mod+I hotkey-overlay-title="桌面中枢" { spawn "dms" "ipc" "call" "dash" "toggle" ""; }
    Mod+N hotkey-overlay-title="通知" { spawn "dms" "ipc" "call" "notifications" "toggle"; }
    Mod+P hotkey-overlay-title="电源" { spawn "dms" "ipc" "call" "powermenu" "toggle"; }
    Mod+R hotkey-overlay-title="启动器" { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
    Mod+Shift+N hotkey-overlay-title="控制中心" { spawn "dms" "ipc" "call" "control-center" "toggle"; }
    Mod+Shift+P hotkey-overlay-title="冻结画面标注" { spawn "dms" "screenshot"; }
    Mod+Shift+Slash hotkey-overlay-title="DMS 快捷键面板" { spawn "dms" "ipc" "call" "keybinds" "toggle" "niri"; }
}
EOF
    fi
  '';

  dmsTraySync = pkgs.writeShellScript "dms-tray-sync" ''
    set -u
    busctl="${pkgs.systemd}/bin/busctl"
    awk="${pkgs.gawk}/bin/awk"
    grep="${pkgs.gnugrep}/bin/grep"
    sleep="${pkgs.coreutils}/bin/sleep"
    seq="${pkgs.coreutils}/bin/seq"

    for _ in $("$seq" 1 20); do
      "$busctl" --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
      "$sleep" 0.25
    done

    for name in $("$busctl" --user list --no-legend 2>/dev/null | "$awk" '{print $1}' | "$grep" -E '^org\.(kde|freedesktop|ayatana)\.StatusNotifierItem-'); do
      "$busctl" --user call org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisterStatusNotifierItem s "$name" >/dev/null 2>&1 || true
    done
  '';

  noctaliaUserTemplates = builtins.replaceStrings
    [ "[theme.templates.user." ]
    [ "[templates." ]
    (builtins.readFile ../noctalia/config/user-templates.toml);

  mkQmlImportPath = qmlPkgs:
    lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtQmlPrefix}") qmlPkgs);

  mkQtPluginPath = qtPkgs:
    lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtPluginPrefix}") qtPkgs);

  dmsRootSrc = pkgs.fetchFromGitHub {
    owner = "duxlabs-dev";
    repo = "dux-shell";
    rev = "9f39bde26340fbe1972b58a4e35ccf66cb4bd2d9";
    hash = "sha256-w2BtCMDjDjAmAKa831CsrPE/pYC0mAQDmor419YimKM=";
  };

  dankQmlCommon = pkgs.fetchFromGitHub {
    owner = "duxlabs-dev";
    repo = "dux-qml-common";
    rev = "be3e16ca62866a749b34cfefe1aaed81cfe21e94";
    hash = "sha256-A266EMSFs169/cqH+9elzMX/6N+ycuEBXFw4qXdTD7k=";
  };

  dmsQtPackages = with pkgs.kdePackages; [
    kirigami.unwrapped
    sonnet
    qtmultimedia
    qtimageformats
    kimageformats
    pkgs.qt6.qtbase
    pkgs.qt6.qtdeclarative
    pkgs.qt6.qt5compat
    pkgs.qt6.qtsvg
    pkgs.qt6.qtwayland
    pkgs.quickshell
  ];

  dmsRuntimeBins = [
    pkgs.quickshell
    pkgs.matugen
    pkgs.cava
    pkgs.glib
    pkgs.networkmanager
    pkgs.wl-clipboard
    pkgs.cliphist
    pkgs.brightnessctl
  ];

  dmsNotificationPatch = pkgs.writeText "dms-patch-notifications.py" ''
    import pathlib
    import sys

    root = pathlib.Path(sys.argv[1])

    def fix(s: str) -> str:
        lines = s.split("\n")
        if len(lines) <= 1 or "notificationPopupBodyInvokesAction: {" in s:
            return s
        return "\n".join([lines[0]] + [("    " + l if l else "") for l in lines[1:]])

    def patch(rel_path: str, old: str, new: str) -> None:
        old = fix(old)
        new = fix(new)
        path = root / rel_path
        text = path.read_text(encoding="utf-8")
        if old not in text:
            raise RuntimeError(f"Patch target not found in {rel_path}")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    patch(
        "Common/settings/SettingsSpec.js",
        "    notificationPopupBodyInvokesAction: {\n        def: false\n    },",
        "    notificationPopupBodyInvokesAction: {\n        def: true\n    },",
    )

    patch(
        "Services/NotificationService.qml",
        "import Quickshell.Services.Notifications",
        "import Quickshell.Services.Notifications\nimport Quickshell.Services.SystemTray",
    )

    patch(
        "Services/NotificationService.qml",
        """    function invokeLastNotification() {
        const w = notifications[notifications.length - 1];
        const actions = w?.actions || [];
        const action = actions.find(a => a.identifier === "default") || actions[0];
        if (!action?.invoke)
            return false;
        action.invoke();
        dismissNotification(w);
        return true;
    }""",
        """    function focusNotificationWindow(notif) {
        if (!notif)
            return false;

        const aliasMap = {
            "chatgpt": ["codex-desktop", "codex", "chatgpt"],
            "codex": ["codex-desktop", "chatgpt"],
            "wechat": ["wechat", "weixin", "com.tencent.wechat", "微信"],
            "微信": ["wechat", "weixin", "com.tencent.wechat", "微信"],
            "qq": ["qq", "linuxqq", "com.tencent.qq"],
            "telegram": ["org.telegram.desktop", "telegram-desktop", "telegram"],
            "zen": ["zen-beta", "zen-browser", "zen", "app.zen_browser.zen"],
            "zen browser": ["zen-beta", "zen-browser", "zen"],
            "wezterm": ["org.wezfurlong.wezterm", "wezterm"],
            "vscode": ["code", "code-url-handler", "vscodium"],
            "code": ["code", "code-url-handler"],
            "antigravity": ["antigravity"]
        };

        const tokens = [];
        function pushUnique(val) {
            const s = String(val || "").toLowerCase().trim().replace(/\\.desktop$/, "");
            if (!s || tokens.indexOf(s) !== -1)
                return;
            tokens.push(s);
        }

        function addCandidate(raw) {
            let s = String(raw || "").toLowerCase().trim();
            if (!s)
                return;
            if (s.indexOf("/") !== -1) {
                s = s.split("/").pop().replace(/\\.(png|svg|xpm|ico|jpg|jpeg|webp)$/i, "");
            }
            s = s.replace(/\\.desktop$/, "");
            if (!s)
                return;
            pushUnique(s);
            if (s.indexOf(".") !== -1) {
                const parts = s.split(".");
                const last = parts[parts.length - 1];
                const prev = parts.length >= 2 ? parts[parts.length - 2] : "";
                if (last === "desktop" && prev)
                    pushUnique(prev);
                else if (last)
                    pushUnique(last);
            }
            const modded = String(Paths.moddedAppId(s) || "").toLowerCase().trim();
            if (modded && modded !== s && modded.indexOf("/") === -1)
                pushUnique(modded);
            try {
                const entry = DesktopEntries.heuristicLookup(s);
                if (entry) {
                    pushUnique(entry.id);
                    pushUnique(entry.name);
                    pushUnique(entry.icon);
                    pushUnique(entry.startupClass);
                }
            } catch (e) {}
        }

        addCandidate(notif.desktopEntry);
        addCandidate(notif.appName);
        addCandidate(notif.appIcon);

        const initialTokens = tokens.slice();
        for (const t of initialTokens) {
            const mapped = aliasMap[t];
            if (mapped) {
                for (const m of mapped)
                    pushUnique(m);
            }
        }

        if (tokens.length === 0)
            return false;

        const summaryLower = String(notif.summary || "").toLowerCase().trim();
        const bodyLower = String(notif.body || "").replace(/<[^>]*>/g, "").toLowerCase().trim();

        if (CompositorService.isNiri && (NiriService.windows?.length ?? 0) > 0) {
            const windows = NiriService.windows;
            const rawScores = [];
            const pidScores = {};

            for (let i = 0; i < windows.length; i++) {
                const w = windows[i];
                const winAppId = String(w.app_id || "").toLowerCase().trim();
                const moddedWinId = winAppId ? String(Paths.moddedAppId(winAppId) || "").toLowerCase().trim() : "";
                const winTitle = String(w.title || "").toLowerCase().trim();
                let score = 0;

                for (const tok of tokens) {
                    if (!tok)
                        continue;
                    if (winAppId && (winAppId === tok || moddedWinId === tok || winAppId.split(".").pop() === tok)) {
                        score = Math.max(score, 120);
                    } else if (winAppId && tok.length >= 2 && winAppId.length >= 2 && (winAppId.includes(tok) || tok.includes(winAppId) || (moddedWinId && moddedWinId.includes(tok)))) {
                        score = Math.max(score, 95);
                    } else if (winTitle && winTitle === tok) {
                        score = Math.max(score, winAppId ? 80 : 45);
                    } else if (winTitle && tok.length >= 2 && (winTitle.endsWith("— " + tok) || winTitle.endsWith("- " + tok) || winTitle.startsWith(tok + " ") || (tok.length >= 3 && winTitle.includes(tok)))) {
                        score = Math.max(score, winAppId ? 60 : 35);
                    }
                }

                rawScores.push(score);
                if (w.pid && score > 0 && winAppId) {
                    pidScores[w.pid] = Math.max(pidScores[w.pid] || 0, score);
                }
            }

            let bestWin = null;
            let bestTotal = 0;
            let bestFocusTime = -1;

            for (let i = 0; i < windows.length; i++) {
                const w = windows[i];
                const effectiveAppScore = Math.max(rawScores[i], (w.pid && pidScores[w.pid]) ? pidScores[w.pid] : 0);
                if (effectiveAppScore <= 0)
                    continue;

                let contentScore = 0;
                const winSize = w.layout?.window_size;
                if (winSize && (winSize[0] < 80 || winSize[1] < 80))
                    contentScore -= 50;

                if (!w.app_id)
                    contentScore -= 30;

                const winTitle = String(w.title || "").toLowerCase().trim();
                const cleanTitle = winTitle.replace(/\\s*[—–-]\\s*[^—–-]+$/, "").replace(/(\\.\\.\\.|…)+$/, "").replace(/^✳\\s*/, "").trim();

                if (summaryLower.length >= 2 && winTitle && (winTitle.includes(summaryLower) || (cleanTitle.length >= 3 && summaryLower.includes(cleanTitle))))
                    contentScore += 45;
                if (bodyLower.length >= 2 && winTitle && (winTitle.includes(bodyLower) || (cleanTitle.length >= 4 && bodyLower.includes(cleanTitle))))
                    contentScore += 40;

                const total = effectiveAppScore + contentScore;
                const focusTime = (w.focus_timestamp?.secs ?? 0) + (w.focus_timestamp?.nanos ?? 0) / 1e9;

                if (total > bestTotal || (total === bestTotal && focusTime > bestFocusTime)) {
                    bestTotal = total;
                    bestFocusTime = focusTime;
                    bestWin = w;
                }
            }

            if (bestWin && bestWin.id !== undefined) {
                CompositorService.closeNiriOverviewOnWindowFocus();
                NiriService.focusWindow(bestWin.id);
                return true;
            }
        }

        const toplevels = CompositorService.sortedToplevels || [];
        for (const tl of toplevels) {
            const tlAppId = String(tl?.appId || "").toLowerCase().trim();
            const tlTitle = String(tl?.title || "").toLowerCase().trim();
            for (const tok of tokens) {
                if ((tlAppId && (tlAppId === tok || tlAppId.includes(tok))) || (tlTitle && tlTitle === tok)) {
                    CompositorService.activateToplevel(tl);
                    return true;
                }
            }
        }

        try {
            const trayItems = (typeof SystemTray !== "undefined" && SystemTray.items) ? (SystemTray.items.values || []) : [];
            for (const item of trayItems) {
                const itemId = String(item?.id || "").toLowerCase().trim();
                const itemTitle = String(item?.title || "").toLowerCase().trim();
                const itemTooltip = String(item?.tooltipTitle || item?.tooltipDescription || "").toLowerCase().trim();
                for (const tok of tokens) {
                    if (tok && (itemId === tok || itemId.includes(tok) || itemTitle === tok || itemTitle.includes(tok) || itemTooltip.includes(tok))) {
                        if (item.activate) {
                            item.activate(0, 0);
                            return true;
                        }
                    }
                }
            }
        } catch (e) {}

        return false;
    }

    function invokeLastNotification() {
        const w = notifications[notifications.length - 1];
        if (!w)
            return false;
        const actions = w?.actions || [];
        const action = actions.find(a => a.identifier === "default") || actions[0];
        if (action?.invoke)
            action.invoke();
        const focused = focusNotificationWindow(w);
        if (!action?.invoke && !focused)
            return false;
        dismissNotification(w);
        return true;
    }""",
    )

    patch(
        "Modules/Notifications/NotificationCard.qml",
        "    property bool bodyInvokesAction: false",
        "    property bool bodyInvokesAction: true",
    )

    patch(
        "Modules/Notifications/NotificationCard.qml",
        """                            if (root.bodyInvokesAction) {
                                root.bodyClicked();
                                return;
                            }""",
        """                            if (root.bodyInvokesAction || !root.canExpand) {
                                root.bodyClicked();
                                return;
                            }""",
    )

    patch(
        "Modules/Notifications/Popup/NotificationPopup.qml",
        "    readonly property bool bodyClickInvokesAction: SettingsData.notificationPopupBodyInvokesAction && (notificationData?.actions?.length ?? 0) > 0",
        "    readonly property bool bodyClickInvokesAction: SettingsData.notificationPopupBodyInvokesAction",
    )

    patch(
        "Modules/Notifications/Popup/NotificationPopup.qml",
        """    function invokeDefaultAction() {
        const action = popupActions.defaultAction(notificationData);
        if (!action?.invoke)
            return;
        action.invoke();
        NotificationService.dismissNotification(notificationData);
    }""",
        """    function invokeDefaultAction() {
        const action = popupActions.defaultAction(notificationData);
        if (action?.invoke)
            action.invoke();
        NotificationService.focusNotificationWindow(notificationData);
        NotificationService.dismissNotification(notificationData);
        win.dismissPopupReliably();
    }""",
    )

    patch(
        "Modules/Notifications/Popup/NotificationPopup.qml",
        """                        onActionRequested: action => {
                            if (!action?.invoke || win.exiting)
                                return;
                            action.invoke();
                            win.dismissPopupReliably();
                        }
                        onBodyClicked: {
                            if (!win.notificationData || win.exiting)
                                return;
                            if (win.bodyClickInvokesAction) {
                                win.invokeDefaultAction();
                                return;
                            }
                            if (canExpand) {
                                win.descriptionExpanded = !win.descriptionExpanded;
                                return;
                            }
                            if (win.notificationData.actions?.length > 0) {
                                win.notificationData.actions[0].invoke();
                                NotificationService.dismissNotification(win.notificationData);
                                return;
                            }
                            win.dismissPopupReliably();
                        }""",
        """                        onActionRequested: action => {
                            if (!action?.invoke || win.exiting)
                                return;
                            action.invoke();
                            NotificationService.focusNotificationWindow(win.notificationData);
                            win.dismissPopupReliably();
                        }
                        onBodyClicked: {
                            if (!win.notificationData || win.exiting)
                                return;
                            if (win.bodyClickInvokesAction) {
                                win.invokeDefaultAction();
                                return;
                            }
                            if (canExpand) {
                                win.descriptionExpanded = !win.descriptionExpanded;
                                return;
                            }
                            win.invokeDefaultAction();
                        }""",
    )

    patch(
        "Modules/Notifications/Center/NotificationCard.qml",
        """    function invokeAction(action) {
        if (!action?.invoke)
            return;
        action.invoke();
        PopoutService.closeNotificationCenter();
    }""",
        """    function invokeAction(action, notifData) {
        const targetNotif = notifData || root.notificationGroup?.latestNotification || null;
        if (action?.invoke)
            action.invoke();
        const focused = NotificationService.focusNotificationWindow(targetNotif);
        if (action?.invoke || focused) {
            if (targetNotif)
                NotificationService.dismissNotification(targetNotif);
            PopoutService.closeNotificationCenter();
        }
    }""",
    )

    patch(
        "Modules/Notifications/Center/NotificationCard.qml",
        """        onActionRequested: action => root.invokeAction(action)
        onBodyClicked: {
            if (groupCount > 1) {
                root.toggleGroup();
                return;
            }
            root.invokeAction(contextActions.defaultAction(notificationData));
        }""",
        """        onActionRequested: action => root.invokeAction(action, notificationData)
        onBodyClicked: {
            if (groupCount > 1) {
                root.toggleGroup();
                return;
            }
            root.invokeAction(contextActions.defaultAction(notificationData), notificationData);
        }""",
    )

    patch(
        "Modules/Notifications/Center/NotificationCard.qml",
        """                    onActionRequested: action => root.invokeAction(action)
                    onBodyClicked: root.invokeAction(contextActions.defaultAction(notificationData))""",
        """                    onActionRequested: action => root.invokeAction(action, notificationData)
                    onBodyClicked: root.invokeAction(contextActions.defaultAction(notificationData), notificationData)""",
    )

    patch(
        "Modules/Notifications/Center/HistoryNotificationCard.qml",
        """    onBodyClicked: {
        if (canExpand)
            expandRequested();
    }""",
        """    onBodyClicked: {
        if (NotificationService.focusNotificationWindow(root.notificationData)) {
            PopoutService.closeNotificationCenter();
            return;
        }
        if (canExpand)
            expandRequested();
    }""",
    )

    patch(
        "Modules/Notifications/Center/NotificationKeyboardController.qml",
        """    function handleEnterKey() {
        const selection = getCurrentSelection();
        const group = NotificationService.groupedNotifications[selection.groupIndex];
        if (!group)
            return;
        const notification = selection.type === "notification" ? group.notifications[selection.notificationIndex] : group.latestNotification;
        const actions = notification?.actions || [];
        const index = actions.findIndex(action => action.identifier === "default");
        executeAction(index < 0 ? 0 : index);
    }""",
        """    function handleEnterKey() {
        const selection = getCurrentSelection();
        const group = NotificationService.groupedNotifications[selection.groupIndex];
        if (!group)
            return;
        const notification = selection.type === "notification" ? group.notifications[selection.notificationIndex] : group.latestNotification;
        const actions = notification?.actions || [];
        const index = actions.findIndex(action => action.identifier === "default");
        if (actions.length > 0) {
            executeAction(index < 0 ? 0 : index);
            NotificationService.focusNotificationWindow(notification);
        } else if (NotificationService.focusNotificationWindow(notification)) {
            NotificationService.dismissNotification(notification);
            if (onClose)
                onClose();
        }
    }""",
    )
  '';

  dms-shell = (pkgs.buildGoModule.override { go = pkgs.go_1_27; }) {
    pname = "dms-shell";
    version = "2.0.0-git-9f39bde";
    src = "${dmsRootSrc}/core";
    vendorHash = "sha256-TZVq/BHFu6brw8MMdGDZWUiZUxtjNjKRKxR8SSV7W50=";

    postPatch = ''
      sed -i 's/^go 1\.27\.[0-9]*/go 1.27.1/' go.mod
    '';

    subPackages = [ "cmd/dms" ];

    ldflags = [
      "-s"
      "-w"
      "-X 'main.Version=2.0.0-git-9f39bde'"
    ];

    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.python3
    ];

    postInstall = ''
      mkdir -p $out/share/quickshell/dms
      tar -C ${dmsRootSrc}/quickshell --mode=u+w --exclude-from=${dmsRootSrc}/scripts/shell-test-excludes.txt -cf - . \
        | tar -C $out/share/quickshell/dms -xf -

      rm -f $out/share/quickshell/dms/DCommon
      tar -C ${dankQmlCommon} --mode=u+w --exclude-from=${dmsRootSrc}/scripts/shell-test-excludes.txt -cf - DCommon \
        | tar -C $out/share/quickshell/dms -xf -

      python3 ${dmsNotificationPatch} "$out/share/quickshell/dms"

      echo "2.0.0-git-9f39bde" > $out/share/quickshell/dms/VERSION

      wrapProgram $out/bin/dms \
        --add-flags "-c $out/share/quickshell/dms" \
        --run 'export DMS_ORIG_NIXPKGS_QT6_QML_IMPORT_PATH="''${NIXPKGS_QT6_QML_IMPORT_PATH:-}"' \
        --run 'export DMS_ORIG_QT_PLUGIN_PATH="''${QT_PLUGIN_PATH:-}"' \
        --prefix PATH : "${lib.makeBinPath dmsRuntimeBins}" \
        --prefix NIXPKGS_QT6_QML_IMPORT_PATH : "${mkQmlImportPath dmsQtPackages}" \
        --prefix QML2_IMPORT_PATH : "${mkQmlImportPath dmsQtPackages}" \
        --prefix QT_PLUGIN_PATH : "${mkQtPluginPath dmsQtPackages}"
    '';

    meta = {
      description = "Dux Modular Shell (DMS 2) for Wayland compositors";
      homepage = "https://duxlabs.dev";
      license = lib.licenses.mit;
      mainProgram = "dms";
      platforms = lib.platforms.linux;
    };
  };

  dmsLauncher = pkgs.writeShellScript "dms-launcher" ''
    # 从 systemd credential 读入 DeepSeek API key，仅注入给 dms 外壳及其插件，
    # 不再依赖 environment.d 把密钥广播给整个会话。
    export DEEPSEEK_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/deepseek_api_key" 2>/dev/null || true)"
    exec ${dms-shell}/bin/dms run --session
  '';
in
{
  # [Packages]
  home.packages = [
    dms-shell
    pkgs.quickshell
    pkgs.cava
  ];

  # [Matugen User Templates Bridge]
  xdg.configFile."matugen/config.toml".text = ''
    [config]

    ${noctaliaUserTemplates}

    # Noctalia Built-in & Community App Templates Bridge
    [templates.niri_noctalia]
    input_path = "${noctaliaAssets}/templates/niri/niri.kdl"
    output_path = "${homeDir}/.config/niri/noctalia.kdl"

    [templates.gtk3_noctalia]
    input_path = "${noctaliaAssets}/templates/gtk/gtk3.css"
    output_path = "${homeDir}/.config/gtk-3.0/noctalia.css"
    post_hook = "bash '${noctaliaAssets}/templates/gtk/apply.sh' {{ mode }} >/dev/null 2>&1 || true"

    [templates.gtk4_noctalia]
    input_path = "${noctaliaAssets}/templates/gtk/gtk4.css"
    output_path = "${homeDir}/.config/gtk-4.0/noctalia.css"

    [templates.qt5_noctalia]
    input_path = "${noctaliaAssets}/templates/qt/qtct.conf"
    output_path = "${homeDir}/.config/qt5ct/colors/noctalia.conf"

    [templates.qt6_noctalia]
    input_path = "${noctaliaAssets}/templates/qt/qtct.conf"
    output_path = "${homeDir}/.config/qt6ct/colors/noctalia.conf"

    [templates.wezterm_noctalia]
    input_path = "${weztermNoctaliaTemplate}"
    output_path = "${homeDir}/.config/wezterm/colors/Noctalia.toml"

    [templates.kitty_noctalia]
    input_path = "${dms-shell}/share/quickshell/dms/matugen/templates/kitty.conf"
    output_path = "${homeDir}/.config/kitty/themes/noctalia.conf"
    post_hook = "pkill -USR1 kitty >/dev/null 2>&1 || true"

    [templates.btop_noctalia]
    input_path = "${noctaliaAssets}/templates/btop/btop.theme"
    output_path = "${homeDir}/.config/btop/themes/noctalia.theme"

    [templates.cava_noctalia]
    input_path = "${noctaliaAssets}/templates/cava/cava.ini"
    output_path = "${homeDir}/.config/cava/themes/noctalia"
    post_hook = "pkill -USR2 cava >/dev/null 2>&1 || true"

    [templates.telegram_noctalia]
    input_path = "${homeDir}/.local/state/noctalia/community-templates/telegram/telegram.tdesktop-theme"
    output_path = "${homeDir}/.config/telegram-desktop/themes/noctalia.tdesktop-theme"

    [templates.obsidian_noctalia]
    input_path = "${homeDir}/.cache/dms/templates/obsidian.css"
    output_path = "${homeDir}/.cache/noctalia/obsidian-snippet.css"
    post_hook = "${dmsObsidianSync} >/dev/null 2>&1 || true"

    [templates.obs_noctalia]
    input_path = "${homeDir}/.local/state/noctalia/community-templates/obs/matugen.obt"
    output_path = "${homeDir}/.config/obs-studio/themes/matugen.obt"

    [templates.zathura_noctalia]
    input_path = "${homeDir}/.local/state/noctalia/community-templates/zathura/zathurarc"
    output_path = "${homeDir}/.config/zathura/noctaliarc"

    [templates.yazi_noctalia]
    input_path = "${homeDir}/.cache/dms/templates/yazi.toml"
    output_path = "${homeDir}/.config/yazi/flavors/noctalia.yazi/flavor.toml"

    [templates.zen_browser_chrome]
    input_path = "${homeDir}/.local/state/noctalia/community-templates/zen-browser/zen-userChrome.css"
    output_path = "${homeDir}/.cache/noctalia/zen-browser/zen-userChrome.css"

    [templates.zen_browser_content]
    input_path = "${homeDir}/.local/state/noctalia/community-templates/zen-browser/zen-userContent.css"
    output_path = "${homeDir}/.cache/noctalia/zen-browser/zen-userContent.css"
    post_hook = "bash '${homeDir}/.local/state/noctalia/community-templates/zen-browser/apply.sh' >/dev/null 2>&1 || true"
  '';

  # [Service]
  systemd.user.services.dms = {
    Unit = {
      Description = "Dux Modular Shell (DMS 2)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "notify";
      BusName = "org.freedesktop.Notifications";
      NotifyAccess = "main";
      Environment = [ "QS_DISABLE_CRASH_HANDLER=1" ];
      # 仅把 DeepSeek API key 以 credential 形式注入给 dms，不再全局广播。
      LoadCredential = "deepseek_api_key:${config.sops.secrets."deepseek_api_key".path}";
      ExecStartPre = "${dmsPrepareCommunityTemplates}";
      ExecStart = "${dmsLauncher}";
      ExecStartPost = [ "${dmsTraySync}" ];
      Restart = "on-failure";
      RestartForceExitStatus = "TEMPFAIL";
      SuccessExitStatus = "TEMPFAIL";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
