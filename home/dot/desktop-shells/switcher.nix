# ---
# Module: Desktop Shell Switcher
# Description: Provide a CLI helper to switch between Noctalia, DMS 2, and Clavis Shell at runtime
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  desktop-shell = pkgs.writeShellApplication {
    name = "desktop-shell";
    runtimeInputs = [
      pkgs.systemd
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.procps
    ];
    text = ''
      set -eu

      sync_tray_items() {
        for _ in $(seq 1 20); do
          busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
          sleep 0.25
        done

        for name in $(busctl --user list --no-legend 2>/dev/null | awk '{print $1}' | grep -E '^org\.(kde|freedesktop|ayatana)\.StatusNotifierItem-' || true); do
          busctl --user call org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisterStatusNotifierItem s "$name" >/dev/null 2>&1 || true
        done
      }

      niri_dms_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/niri/dms"
      binds_file="$niri_dms_dir/binds.kdl"
      dms_binds_backup="$niri_dms_dir/binds.dms.kdl"

      ensure_niri_dms_files() {
        mkdir -p "$niri_dms_dir"
        touch "$binds_file" "$niri_dms_dir/wpblur.kdl" "$niri_dms_dir/windowrules.kdl"
      }

      save_dms_binds_if_present() {
        if [ -s "$binds_file" ] && grep -q 'spawn "dms"' "$binds_file" 2>/dev/null; then
          cp "$binds_file" "$dms_binds_backup"
        fi
      }

      write_default_dms_binds() {
        cat > "$1" <<'EOF'
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
      }

      write_clavis_binds() {
        cat > "$1" <<'EOF'
binds {
    Mod+B hotkey-overlay-title="剪贴板" { spawn "key" "ipc" "call" "keystone" "tools"; }
    Mod+I hotkey-overlay-title="桌面中枢" { spawn "key" "ipc" "call" "keystone" "dashboard"; }
    Mod+N hotkey-overlay-title="通知" { spawn "key" "ipc" "call" "sidebar" "toggle" "right"; }
    Mod+P hotkey-overlay-title="电源" { spawn "key" "ipc" "call" "power-menu" "toggle"; }
    Mod+R hotkey-overlay-title="启动器" { spawn "key" "ipc" "call" "spotlight" "toggle"; }
    Mod+Shift+N hotkey-overlay-title="控制中心" { spawn "key" "ipc" "call" "control-center" "toggle" ""; }
    Mod+Shift+P hotkey-overlay-title="冻结画面标注" { spawn "key" "--region"; }
    Mod+Shift+Slash hotkey-overlay-title="Clavis 快捷键面板" { spawn "key" "ipc" "call" "shortcut-map" "toggle"; }
}
EOF
      }

      stop_all_shells() {
        systemctl --user stop \
          niri-bar-sync.service \
          dms.service \
          clavis-shell.service \
          clavis-clipboard.service 2>/dev/null || true
        pkill -x quickshell 2>/dev/null || true
        sleep 0.4
      }

      show_status() {
        for unit in dms.service clavis-shell.service clavis-clipboard.service; do
          state="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
          printf '%-26s %s\n' "$unit:" "$state"
        done
      }

      cmd="''${1:-status}"
      case "$cmd" in
        status)
          show_status
          ;;
        dms|dms2|dux)
          echo "正在切换到 DMS 2 (Dux Shell)..."
          ensure_niri_dms_files
          if [ -s "$dms_binds_backup" ]; then
            cp "$dms_binds_backup" "$binds_file"
          elif ! grep -q 'spawn "dms"' "$binds_file" 2>/dev/null; then
            write_default_dms_binds "$binds_file"
          fi
          stop_all_shells
          systemctl --user start dms.service niri-bar-sync.service
          sync_tray_items
          show_status
          ;;
        clavis|qs)
          echo "正在切换到 Clavis Shell (StatIndet/quickshell)..."
          ensure_niri_dms_files
          save_dms_binds_if_present
          write_clavis_binds "$binds_file"
          stop_all_shells
          systemctl --user start clavis-clipboard.service clavis-shell.service
          sync_tray_items
          show_status
          ;;
        *)
          echo "用法: desktop-shell <status|dms|clavis>" >&2
          exit 64
          ;;
      esac
    '';
  };
in
{
  home.packages = [
    desktop-shell
  ];
}
