# ---
# Module: Mihomo Lifecycle Authorization
# Description: Grants dot a fixed, least-privilege control path for the local Mihomo service.
# Scope: System
# ---
# Notes:
# - This is the host-side privilege boundary used by the independent Noctalia plugin.
# - It intentionally cannot enable, disable, mask, or target any service other than mihomo.service.

{ pkgs, ... }:
let
  mihomoLifecycle = pkgs.writeShellApplication {
    name = "mihomo-lifecycle";
    runtimeInputs = [ pkgs.coreutils pkgs.systemd ];
    text = ''
      set -eu

      [ "$#" -eq 1 ] || exit 64
      case "$1" in
        status)
          if timeout 10s systemctl --system is-active --quiet mihomo.service; then
            printf 'running\n'
          elif systemctl --system is-failed --quiet mihomo.service; then
            exit 1
          else
            printf 'stopped\n'
          fi
          ;;
        start|stop|restart)
          exec timeout 12s systemctl --system --no-ask-password "$1" mihomo.service
          ;;
        *)
          exit 64
          ;;
      esac
    '';
  };
in
{
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "dot" &&
          action.lookup("unit") == "mihomo.service" &&
          ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [ mihomoLifecycle ];
}
