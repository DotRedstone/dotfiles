import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

// [Daemon] Owns the Kimpanel bridge process and resolves the cursor anchor.
PluginComponent {
    id: root

    property string bridgeCommand: "@bridge@"

    // [State] Latest snapshot pushed by the bridge (protocol v1)
    property var panel: ({
            "visible": false,
            "preedit": "",
            "caret": 0,
            "aux": "",
            "candidates": [],
            "cursor": -1,
            "hasPrev": false,
            "hasNext": false,
            "layout": 0,
            "spot": null,
            "win": null
        })

    // [Geometry] Niri window geometry turns relative spot rects into global ones
    readonly property var focusedWindow: NiriService.windows.find(w => w.is_focused) ?? null
    readonly property string focusedOutput: {
        const wsId = panel.win?.workspaceId ?? focusedWindow?.workspace_id;
        const ws = (wsId !== undefined && wsId !== null) ? NiriService.workspaces[wsId] : null;
        return ws?.output ?? "";
    }
    readonly property var focusedWindowRect: {
        const out = NiriService.outputs[focusedOutput]?.logical ?? { "x": 0, "y": 0 };
        if (panel.win) {
            return {
                "x": out.x + panel.win.x,
                "y": out.y + panel.win.y,
                "w": panel.win.w,
                "h": panel.win.h
            };
        }
        const win = focusedWindow;
        const lay = win?.layout;
        const tile = lay?.tile_pos_in_workspace_view;
        if (!tile || !lay.window_size)
            return null;
        const off = lay.window_offset_in_tile ?? [0, 0];
        return {
            "x": out.x + tile[0] + off[0],
            "y": out.y + tile[1] + off[1],
            "w": lay.window_size[0],
            "h": lay.window_size[1]
        };
    }
    readonly property var anchor: {
        const s = panel.spot;
        if (!s || (s.x <= 0 && s.y <= 0))
            return null;
        if (!s.relative)
            return {
                "x": s.x,
                "y": s.y,
                "w": s.w,
                "h": s.h
            };
        const win = focusedWindowRect;
        if (!win)
            return null;
        return {
            "x": win.x + s.x,
            "y": win.y + s.y,
            "w": s.w,
            "h": s.h
        };
    }

    function send(cmd) {
        if (bridge.running)
            bridge.write(cmd + "\n");
    }

    Process {
        id: bridge
        command: [root.bridgeCommand]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line);
                    if (data.v === 1)
                        root.panel = data;
                } catch (e) {
                    console.warn("fcitxKimpanel: bad bridge line", e);
                }
            }
        }

        stderr: SplitParser {
            onRead: line => console.info(line)
        }

        onExited: (code, status) => {
            root.panel = Object.assign({}, root.panel, {
                "visible": false
            });
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 1500
        onTriggered: bridge.running = true
    }

    Variants {
        model: Quickshell.screens

        delegate: CandidatePopup {
            required property var modelData
            screen: modelData
            daemon: root
        }
    }
}
