# ---
# Module: Niri Mac-style Shortcuts
# Description: Context-aware shortcuts for Niri
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  niri-mac-shortcut = pkgs.writeShellScriptBin "niri-mac-shortcut" ''
    WINDOW_JSON=$(niri msg --json focused-window 2>/dev/null || echo "")
    APP_ID=$(printf '%s' "$WINDOW_JSON" | ${pkgs.jq}/bin/jq -r '.app_id // ""' 2>/dev/null || echo "")
    WINDOW_PID=$(printf '%s' "$WINDOW_JSON" | ${pkgs.jq}/bin/jq -r '.pid // ""' 2>/dev/null || echo "")

    # Niri 报告的 XWayland 窗口 PID 是 xwayland-satellite 本身。
    is_xwayland() {
      [ -n "$WINDOW_PID" ] || return 1
      case "$(${pkgs.coreutils}/bin/readlink "/proc/$WINDOW_PID/exe" 2>/dev/null)" in
        *xwayland-satellite*) return 0 ;;
        *) return 1 ;;
      esac
    }

    # 用法：send_keys <ctrl|ctrl_shift> <key>
    # wtype 的虚拟键盘映射不会被 XWayland 采用，键码按物理映射解释，Ctrl+V 会
    # 变成 Ctrl+Escape。XWayland 窗口因此改用 xdotool 经 XTEST 直接向 X 服务器
    # 注入：不经过 Niri 的座位状态，不与仍按住的物理 Super / 字母键冲突。
    # 注入前在 X 侧松开 Super 且不恢复：Niri 仍认为 Super 按住，连按仍会触发
    # 快捷键；若像 --clearmodifiers 那样恢复，物理 Super 先松开时会在 X 侧卡住。
    send_keys() {
      if is_xwayland; then
        if [ "$1" = ctrl_shift ]; then
          combo="ctrl+shift+$2"
        else
          combo="ctrl+$2"
        fi
        DISPLAY="''${DISPLAY:-:0}" ${pkgs.xdotool}/bin/xdotool keyup --delay 1 Super_L Super_R key --delay 1 "$combo"
      elif [ "$1" = ctrl_shift ]; then
        # `wtype -M` 只按下修饰键而不会自动释放，因此按相反顺序显式释放。
        ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k "$2" -m shift -m ctrl
      else
        ${pkgs.wtype}/bin/wtype -M ctrl -k "$2" -m ctrl
      fi
    }

    send_ctrl() {
      send_keys ctrl "$1"
    }

    send_ctrl_shift() {
      send_keys ctrl_shift "$1"
    }

    # Terminal detection
    is_terminal() {
      [[ "$APP_ID" == *"wezterm"* ]] || \
      [[ "$APP_ID" == "foot" ]] || \
      [[ "$APP_ID" == "alacritty" ]] || \
      [[ "$APP_ID" == "kitty" ]]
    }

    case "$1" in
      copy)
        if is_terminal; then
          send_ctrl_shift c
        else
          send_ctrl c
        fi
        ;;
      paste)
        if is_terminal; then
          send_ctrl_shift v
        else
          send_ctrl v
        fi
        ;;
      cut)
        if ! is_terminal; then
          send_ctrl x
        fi
        ;;
      undo)
        if ! is_terminal; then
          send_ctrl z
        fi
        ;;
      redo)
        if ! is_terminal; then
          send_ctrl_shift z
        fi
        ;;
      select-all)
        if ! is_terminal; then
          send_ctrl a
        fi
        ;;
      save)
        if ! is_terminal; then
          send_ctrl s
        fi
        ;;
      paste-plain)
        send_ctrl_shift v
        ;;
      esac
  '';

  niri-power-key = pkgs.writeShellScriptBin "niri-power-key" ''
    set -u

    session_id="''${XDG_SESSION_ID:-}"
    if [ -z "$session_id" ]; then
      session_id="$(
        ${pkgs.systemd}/bin/loginctl list-sessions --no-legend 2>/dev/null \
          | ${pkgs.gawk}/bin/awk -v user="''${USER:-dot}" '$3 == user { print $1; exit }'
      )"
    fi

    locked="no"
    if [ -n "$session_id" ]; then
      locked="$(${pkgs.systemd}/bin/loginctl show-session "$session_id" -p LockedHint --value 2>/dev/null || printf 'no')"
    fi

    if [ "$locked" = "yes" ]; then
      niri msg action power-on-monitors >/dev/null 2>&1 || noctalia msg dpms-on >/dev/null 2>&1 || true
      exit 0
    fi

    niri msg action power-on-monitors >/dev/null 2>&1 || true
    if ${pkgs.systemd}/bin/systemctl --user is-active --quiet dms.service; then
      dms ipc call lock lock >/dev/null 2>&1 || true
    elif ${pkgs.systemd}/bin/systemctl --user is-active --quiet clavis-shell.service; then
      key ipc call lock open >/dev/null 2>&1 || true
    fi
    if [ -n "$session_id" ]; then
      ${pkgs.systemd}/bin/loginctl lock-session "$session_id" >/dev/null 2>&1 || ${pkgs.systemd}/bin/loginctl lock-sessions >/dev/null 2>&1 || true
    else
      ${pkgs.systemd}/bin/loginctl lock-sessions >/dev/null 2>&1 || true
    fi
    ${pkgs.coreutils}/bin/sleep 0.8
    niri msg action power-off-monitors >/dev/null 2>&1 || noctalia msg dpms-off >/dev/null 2>&1 || true
  '';

  niri-fullscreen-toggle = pkgs.writeShellScriptBin "niri-fullscreen-toggle" ''
    set -u

    bar_show() {
      if ${pkgs.systemd}/bin/systemctl --user is-active --quiet dms.service; then
        dms ipc call bar reveal id default >/dev/null 2>&1 || true
      elif ${pkgs.systemd}/bin/systemctl --user is-active --quiet noctalia.service; then
        noctalia msg bar-show default >/dev/null 2>&1 || true
      fi
    }

    bar_hide() {
      if ${pkgs.systemd}/bin/systemctl --user is-active --quiet dms.service; then
        dms ipc call bar hide id default >/dev/null 2>&1 || true
      elif ${pkgs.systemd}/bin/systemctl --user is-active --quiet noctalia.service; then
        noctalia msg bar-hide default >/dev/null 2>&1 || true
      fi
    }

    state_dir="''${XDG_RUNTIME_DIR:-/tmp}/niri-fullscreen-toggle"
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

    window_json="$(niri msg --json focused-window 2>/dev/null || true)"
    if [ -z "$window_json" ] || [ "$window_json" = "null" ]; then
      bar_show
      niri msg action fullscreen-window >/dev/null 2>&1 || true
      exit 0
    fi

    window_id="$(printf '%s' "$window_json" | ${pkgs.jq}/bin/jq -r '.id // empty' 2>/dev/null || true)"
    output_json="$(niri msg --json focused-output 2>/dev/null || true)"
    window_width="$(printf '%s' "$window_json" | ${pkgs.jq}/bin/jq -r '(.layout.window_size[0] // 0) | floor' 2>/dev/null || printf 0)"
    window_height="$(printf '%s' "$window_json" | ${pkgs.jq}/bin/jq -r '(.layout.window_size[1] // 0) | floor' 2>/dev/null || printf 0)"
    output_width="$(printf '%s' "$output_json" | ${pkgs.jq}/bin/jq -r '(.logical.width // 0) | floor' 2>/dev/null || printf 0)"
    output_height="$(printf '%s' "$output_json" | ${pkgs.jq}/bin/jq -r '(.logical.height // 0) | floor' 2>/dev/null || printf 0)"

    is_fullscreen=0
    if [ "$output_width" -gt 0 ] && [ "$output_height" -gt 0 ]; then
      if [ "$window_width" -ge "$((output_width - 2))" ] && [ "$window_height" -ge "$((output_height - 2))" ]; then
        is_fullscreen=1
      fi
    fi

    state_file="$state_dir/window-$window_id"
    if [ -n "$window_id" ] && { [ -e "$state_file" ] || [ "$is_fullscreen" -eq 1 ]; }; then
      niri msg action fullscreen-window >/dev/null 2>&1 || true
      ${pkgs.coreutils}/bin/rm -f "$state_file" >/dev/null 2>&1 || true
      bar_show
    else
      bar_hide
      if [ -n "$window_id" ]; then
        printf '%s\n' "$window_id" > "$state_file"
      fi
      niri msg action fullscreen-window >/dev/null 2>&1 || true
    fi
  '';

  niri-bar-sync = pkgs.writeShellScriptBin "niri-bar-sync" ''
    set -u

    state_dir="''${XDG_RUNTIME_DIR:-/tmp}/niri-fullscreen-toggle"
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

    bar_show() {
      if ${pkgs.systemd}/bin/systemctl --user is-active --quiet dms.service; then
        dms ipc call bar reveal id default >/dev/null 2>&1 || true
      elif ${pkgs.systemd}/bin/systemctl --user is-active --quiet noctalia.service; then
        noctalia msg bar-show default >/dev/null 2>&1 || true
      fi
    }

    bar_hide() {
      if ${pkgs.systemd}/bin/systemctl --user is-active --quiet dms.service; then
        dms ipc call bar hide id default >/dev/null 2>&1 || true
      elif ${pkgs.systemd}/bin/systemctl --user is-active --quiet noctalia.service; then
        noctalia msg bar-hide default >/dev/null 2>&1 || true
      fi
    }

    is_focused_window_tracked_fullscreen() {
      window_json="$(niri msg --json focused-window 2>/dev/null || true)"
      if [ -z "$window_json" ] || [ "$window_json" = "null" ]; then
        return 1
      fi

      window_id="$(printf '%s' "$window_json" | ${pkgs.jq}/bin/jq -r '.id // empty' 2>/dev/null || true)"
      if [ -z "$window_id" ] || [ ! -e "$state_dir/window-$window_id" ]; then
        return 1
      fi

      output_json="$(niri msg --json focused-output 2>/dev/null || true)"
      window_width="$(printf '%s' "$window_json" | ${pkgs.jq}/bin/jq -r '(.layout.window_size[0] // 0) | floor' 2>/dev/null || printf 0)"
      window_height="$(printf '%s' "$window_json" | ${pkgs.jq}/bin/jq -r '(.layout.window_size[1] // 0) | floor' 2>/dev/null || printf 0)"
      output_width="$(printf '%s' "$output_json" | ${pkgs.jq}/bin/jq -r '(.logical.width // 0) | floor' 2>/dev/null || printf 0)"
      output_height="$(printf '%s' "$output_json" | ${pkgs.jq}/bin/jq -r '(.logical.height // 0) | floor' 2>/dev/null || printf 0)"

      [ "$output_width" -gt 0 ] && [ "$output_height" -gt 0 ] \
        && [ "$window_width" -ge "$((output_width - 2))" ] \
        && [ "$window_height" -ge "$((output_height - 2))" ]
    }

    cleanup_stale_state() {
      windows_json="$(niri msg --json windows 2>/dev/null || true)"
      [ -z "$windows_json" ] && return 0

      for state_file in "$state_dir"/window-*; do
        [ -e "$state_file" ] || continue
        window_id="''${state_file##*/window-}"
        if ! printf '%s' "$windows_json" | ${pkgs.jq}/bin/jq -e --argjson id "$window_id" 'any(.[]; .id == $id)' >/dev/null 2>&1; then
          ${pkgs.coreutils}/bin/rm -f "$state_file" >/dev/null 2>&1 || true
        fi
      done
    }

    sync_bar() {
      cleanup_stale_state

      if is_focused_window_tracked_fullscreen; then
        bar_hide
      else
        bar_show
      fi
    }

    sync_bar
    while :; do
      ${pkgs.coreutils}/bin/timeout 5s niri msg --json event-stream 2>/dev/null | while IFS= read -r event; do
        case "$event" in
          *WindowsChanged*|*WorkspacesChanged*|*WindowFocusChanged*|*WindowOpenedOrChanged*|*WindowClosed*|*WorkspaceActivated*|*Output*)
            sync_bar
            ;;
        esac
      done

      sync_bar
      ${pkgs.coreutils}/bin/sleep 0.2
    done
  '';
in
{
  home.packages = [
    niri-mac-shortcut
    niri-power-key
    niri-fullscreen-toggle
    niri-bar-sync
  ];

  systemd.user.services.niri-bar-sync = {
    Unit = {
      Description = "Keep desktop shell bar visible outside Niri fullscreen";
      After = [ "graphical-session.target" "dms.service" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${niri-bar-sync}/bin/niri-bar-sync";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
