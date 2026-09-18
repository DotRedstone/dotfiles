# ---
# Module: Niri Mac-style Shortcuts
# Description: Context-aware shortcuts for Niri
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  niri-mac-shortcut = pkgs.writeShellScriptBin "niri-mac-shortcut" ''
    # Get the app_id of the focused window
    APP_ID=$(niri msg --json focused-window 2>/dev/null | ${pkgs.jq}/bin/jq -r '.app_id // ""' 2>/dev/null || echo "")

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
          ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k c
        else
          ${pkgs.wtype}/bin/wtype -M ctrl -k c
        fi
        ;;
      paste)
        if is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k v
        else
          ${pkgs.wtype}/bin/wtype -M ctrl -k v
        fi
        ;;
      cut)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -k x
        fi
        ;;
      undo)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -k z
        fi
        ;;
      redo)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k z
        fi
        ;;
      select-all)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -k a
        fi
        ;;
      save)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -k s
        fi
        ;;
      paste-plain)
        ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k v
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

    state_dir="''${XDG_RUNTIME_DIR:-/tmp}/niri-fullscreen-toggle"
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

    window_json="$(niri msg --json focused-window 2>/dev/null || true)"
    if [ -z "$window_json" ] || [ "$window_json" = "null" ]; then
      noctalia msg bar-show default >/dev/null 2>&1 || true
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
      noctalia msg bar-show default >/dev/null 2>&1 || true
    else
      noctalia msg bar-hide default >/dev/null 2>&1 || true
      if [ -n "$window_id" ]; then
        printf '%s\n' "$window_id" > "$state_file"
      fi
      niri msg action fullscreen-window >/dev/null 2>&1 || true
    fi
  '';

  niri-noctalia-bar-sync = pkgs.writeShellScriptBin "niri-noctalia-bar-sync" ''
    set -u

    state_dir="''${XDG_RUNTIME_DIR:-/tmp}/niri-fullscreen-toggle"
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

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
        noctalia msg bar-hide default >/dev/null 2>&1 || true
      else
        noctalia msg bar-show default >/dev/null 2>&1 || true
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
    niri-noctalia-bar-sync
  ];

  systemd.user.services.niri-noctalia-bar-sync = {
    Unit = {
      Description = "Keep Noctalia bar visible outside Niri fullscreen";
      After = [ "graphical-session.target" "noctalia.service" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${niri-noctalia-bar-sync}/bin/niri-noctalia-bar-sync";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
