# ---
# Module: Auto Clicker
# Description: Provide a Wayland-compatible left-click repeater with a global toggle
# Scope: Home Manager
# ---
# Notes:
# - The click loop is inactive by default and is stopped explicitly or by toggling it again.
# - ydotoold is system-managed because Wayland clients cannot inject pointer clicks directly.

{ pkgs, ... }:
let
  autoclickerRunner = pkgs.writeShellApplication {
    name = "autoclicker-run";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.ydotool ];
    text = ''
      set -eu

      cps="''${1:-12}"
      case "$cps" in
        ""|*[!0-9]*)
          printf 'autoclicker: clicks per second must be an integer from 1 to 30\n' >&2
          exit 2
          ;;
      esac

      if [ "$cps" -lt 1 ] || [ "$cps" -gt 30 ]; then
        printf 'autoclicker: clicks per second must be from 1 to 30\n' >&2
        exit 2
      fi

      interval="$(${pkgs.gawk}/bin/awk -v cps="$cps" 'BEGIN { printf "%.6f", 1 / cps }')"
      while :; do
        ${pkgs.ydotool}/bin/ydotool click 0xC0
        ${pkgs.coreutils}/bin/sleep "$interval"
      done
    '';
  };

  autoclicker = pkgs.writeShellApplication {
    name = "autoclicker";
    runtimeInputs = [ pkgs.gnugrep pkgs.libnotify pkgs.systemd ];
    text = ''
      set -eu

      systemctl="${pkgs.systemd}/bin/systemctl"
      notify="${pkgs.libnotify}/bin/notify-send"
      grep="${pkgs.gnugrep}/bin/grep"
      default_cps=12

      is_running() {
        "$systemctl" --user --type=service --state=running --no-legend --plain \
          | "$grep" -q '^autoclicker@'
      }

      start() {
        cps="''${1:-$default_cps}"
        "$systemctl" --user start "autoclicker@$cps.service"
        "$notify" --app-name="连点器" "连点器已启动" "左键：$cps 次/秒；再次按 Super+Shift+F6 停止。"
      }

      stop() {
        "$systemctl" --user stop 'autoclicker@*.service'
        "$notify" --app-name="连点器" "连点器已停止"
      }

      case "''${1:-toggle}" in
        start)
          start "''${2:-$default_cps}"
          ;;
        stop)
          stop
          ;;
        toggle)
          if is_running; then
            stop
          else
            start "''${2:-$default_cps}"
          fi
          ;;
        status)
          if is_running; then
            printf 'running\n'
          else
            printf 'stopped\n'
          fi
          ;;
        *)
          printf 'Usage: autoclicker [start|stop|toggle|status] [clicks-per-second]\n' >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  home.packages = [ autoclicker ];

  systemd.user.services."autoclicker@" = {
    Unit.Description = "Auto clicker (%i clicks per second)";

    Service = {
      ExecStart = "${autoclickerRunner}/bin/autoclicker-run %i";
      Restart = "no";
    };
  };

  xdg.desktopEntries.autoclicker = {
    name = "连点器";
    comment = "切换左键连点器（12 次/秒）";
    exec = "autoclicker toggle";
    icon = "input-mouse";
    terminal = false;
    categories = [ "Utility" ];
  };
}
