# ---
# Module: WeChat X11 Clipboard Bridge
# Description: Bridge WeChat's XWayland clipboard with the Wayland session clipboard
# Scope: Home Manager
# Notes:
# - Supports text plus common image MIME types; file lists still depend on native XWayland support.
# - Keep this local to WeChat/XWayland instead of changing global clipboard behavior.
# ---

{ pkgs, ... }:
let
  bridge = pkgs.writeShellScriptBin "wechat-x11-clipboard-bridge" ''
    set -u

    export DISPLAY="''${WECHAT_X11_DISPLAY:-''${DISPLAY:-:0}}"
    export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    state_dir="$runtime_dir/wechat-x11-clipboard-bridge"
    mkdir -p "$state_dir"

    wl_from_x11_sig="$state_dir/wl-from-x11.sig"
    x11_from_wl_sig="$state_dir/x11-from-wl.sig"
    last_wayland_sig="$state_dir/last-wayland.sig"
    xclip_pid_file="$state_dir/xclip.pid"

    sha_file() {
      ${pkgs.coreutils}/bin/sha256sum "$1" | ${pkgs.coreutils}/bin/cut -d' ' -f1
    }

    is_text_mime() {
      case "$1" in
        text/*|UTF8_STRING|STRING|TEXT)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
    }

    choose_wayland_mime() {
      types_file="$(${pkgs.coreutils}/bin/mktemp "$state_dir/wl-types.XXXXXX")"
      ${pkgs.wl-clipboard}/bin/wl-paste --list-types > "$types_file" 2>/dev/null || true

      for mime in image/png image/jpeg image/jpg image/webp image/bmp image/gif; do
        if ${pkgs.gnugrep}/bin/grep -Fxq "$mime" "$types_file"; then
          printf '%s\n' "$mime"
          ${pkgs.coreutils}/bin/rm -f "$types_file"
          return 0
        fi
      done

      for mime in "text/plain;charset=utf-8" text/plain UTF8_STRING STRING TEXT; do
        if ${pkgs.gnugrep}/bin/grep -Fxq "$mime" "$types_file"; then
          printf '%s\n' "$mime"
          ${pkgs.coreutils}/bin/rm -f "$types_file"
          return 0
        fi
      done

      text_mime="$(${pkgs.gnugrep}/bin/grep -E '^text/' "$types_file" | ${pkgs.coreutils}/bin/head -n 1 || true)"
      if [ -n "$text_mime" ]; then
        printf '%s\n' "$text_mime"
        ${pkgs.coreutils}/bin/rm -f "$types_file"
        return 0
      fi

      ${pkgs.coreutils}/bin/rm -f "$types_file"
      return 1
    }

    choose_x11_target() {
      targets_file="$(${pkgs.coreutils}/bin/mktemp "$state_dir/x11-targets.XXXXXX")"
      DISPLAY="$DISPLAY" ${pkgs.coreutils}/bin/timeout 1s ${pkgs.xclip}/bin/xclip -selection clipboard -o -target TARGETS > "$targets_file" 2>/dev/null || true

      for target in image/png image/jpeg image/jpg image/webp image/bmp image/gif; do
        if ${pkgs.gnugrep}/bin/grep -Fxq "$target" "$targets_file"; then
          printf '%s\n' "$target"
          ${pkgs.coreutils}/bin/rm -f "$targets_file"
          return 0
        fi
      done

      for target in UTF8_STRING text/plain STRING TEXT; do
        if ${pkgs.gnugrep}/bin/grep -Fxq "$target" "$targets_file"; then
          printf '%s\n' "$target"
          ${pkgs.coreutils}/bin/rm -f "$targets_file"
          return 0
        fi
      done

      ${pkgs.coreutils}/bin/rm -f "$targets_file"
      return 1
    }

    kill_xclip_owner() {
      if [ -s "$xclip_pid_file" ]; then
        old_pid="$(${pkgs.coreutils}/bin/cat "$xclip_pid_file" 2>/dev/null || true)"
        if [ -n "$old_pid" ]; then
          ${pkgs.coreutils}/bin/kill "$old_pid" >/dev/null 2>&1 || true
        fi
      fi
      : > "$xclip_pid_file"
    }

    xclip_owner_alive() {
      if [ -s "$xclip_pid_file" ]; then
        old_pid="$(${pkgs.coreutils}/bin/cat "$xclip_pid_file" 2>/dev/null || true)"
        if [ -n "$old_pid" ] && ${pkgs.coreutils}/bin/kill -0 "$old_pid" >/dev/null 2>&1; then
          return 0
        fi
      fi
      return 1
    }

    push_wayland_snapshot_to_x11() {
      mime="$(choose_wayland_mime || true)"
      [ -n "$mime" ] || return 0

      tmp="$(${pkgs.coreutils}/bin/mktemp "$state_dir/wayland.XXXXXX")"
      if is_text_mime "$mime"; then
        ${pkgs.wl-clipboard}/bin/wl-paste --no-newline --type "$mime" > "$tmp" 2>/dev/null || {
          ${pkgs.coreutils}/bin/rm -f "$tmp"
          return 0
        }
      else
        ${pkgs.wl-clipboard}/bin/wl-paste --type "$mime" > "$tmp" 2>/dev/null || {
          ${pkgs.coreutils}/bin/rm -f "$tmp"
          return 0
        }
      fi

      if [ ! -s "$tmp" ]; then
        ${pkgs.coreutils}/bin/rm -f "$tmp"
        return 0
      fi

      hash="$(sha_file "$tmp")"
      sig="$mime:$hash"
      if [ -s "$last_wayland_sig" ] && [ "$sig" = "$(${pkgs.coreutils}/bin/cat "$last_wayland_sig")" ]; then
        ${pkgs.coreutils}/bin/rm -f "$tmp"
        return 0
      fi

      printf '%s\n' "$sig" > "$last_wayland_sig"
      if [ -s "$wl_from_x11_sig" ] && [ "$sig" = "$(${pkgs.coreutils}/bin/cat "$wl_from_x11_sig")" ]; then
        ${pkgs.coreutils}/bin/rm -f "$tmp"
        return 0
      fi

      printf '%s\n' "$sig" > "$x11_from_wl_sig"
      kill_xclip_owner

      if is_text_mime "$mime"; then
        DISPLAY="$DISPLAY" ${pkgs.xclip}/bin/xclip -quiet -selection clipboard -i < "$tmp" >/dev/null 2>&1 &
      else
        DISPLAY="$DISPLAY" ${pkgs.xclip}/bin/xclip -quiet -selection clipboard -target "$mime" -i < "$tmp" >/dev/null 2>&1 &
      fi

      printf '%s\n' "$!" > "$xclip_pid_file"
      ${pkgs.coreutils}/bin/rm -f "$tmp"
    }

    poll_wayland() {
      while :; do
        push_wayland_snapshot_to_x11
        ${pkgs.coreutils}/bin/sleep 1
      done
    }

    poll_x11() {
      last_sig=""
      while :; do
        if xclip_owner_alive; then
          ${pkgs.coreutils}/bin/sleep 1
          continue
        fi

        target="$(choose_x11_target || true)"
        [ -n "$target" ] || {
          ${pkgs.coreutils}/bin/sleep 1
          continue
        }

        tmp="$(${pkgs.coreutils}/bin/mktemp "$state_dir/x11.XXXXXX")"
        if DISPLAY="$DISPLAY" ${pkgs.coreutils}/bin/timeout 1s ${pkgs.xclip}/bin/xclip -selection clipboard -o -target "$target" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
          hash="$(sha_file "$tmp")"
          if is_text_mime "$target"; then
            wl_mime="text/plain;charset=utf-8"
          else
            wl_mime="$target"
          fi
          sig="$wl_mime:$hash"
          if [ "$sig" != "$last_sig" ]; then
            last_sig="$sig"
            if [ -s "$x11_from_wl_sig" ] && [ "$sig" = "$(${pkgs.coreutils}/bin/cat "$x11_from_wl_sig")" ]; then
              :
            else
              printf '%s\n' "$sig" > "$wl_from_x11_sig"
              ${pkgs.wl-clipboard}/bin/wl-copy --type "$wl_mime" < "$tmp" >/dev/null 2>&1 || true
            fi
          fi
        fi
        ${pkgs.coreutils}/bin/rm -f "$tmp"
        ${pkgs.coreutils}/bin/sleep 1
      done
    }

    case "''${1:-run}" in
      push-wayland-to-x11)
        push_wayland_snapshot_to_x11
        ;;
      run)
        push_wayland_snapshot_to_x11
        poll_wayland &
        wayland_pid="$!"
        poll_x11 &
        x11_pid="$!"
        trap 'kill "$wayland_pid" "$x11_pid" >/dev/null 2>&1 || true; kill_xclip_owner' INT TERM EXIT
        wait -n "$wayland_pid" "$x11_pid"
        ;;
      *)
        echo "usage: wechat-x11-clipboard-bridge [run|push-wayland-to-x11]" >&2
        exit 2
        ;;
    esac
  '';
in
{
  home.packages = [ bridge ];

  systemd.user.services.wechat-x11-clipboard-bridge = {
    Unit = {
      Description = "Bridge WeChat XWayland clipboard with Wayland clipboard";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${bridge}/bin/wechat-x11-clipboard-bridge";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
