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
    # bar 的全屏隐藏由 DMS 的 hideOnFullscreen 原生处理（纯内存态，不写 settings），
    # 这里只做全屏切换，避免通过 bar IPC 反复改写 visible 触发整棵控件树重建。
    exec niri msg action fullscreen-window
  '';

in
{
  home.packages = [
    niri-mac-shortcut
    niri-power-key
    niri-fullscreen-toggle
  ];
}
