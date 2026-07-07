# ---
# Module: Noctalia User Service
# Description: Run Noctalia shell under the user systemd session
# Scope: Home Manager
# ---
# Notes:
# - Keep Niri startup responsible for compositor helpers only; systemd owns the shell lifetime.
# - ExecStartPre only removes Noctalia's runtime sockets, not user data or generated config.

{ config, pkgs, ... }:
{
  systemd.user.services.noctalia = {
    Unit = {
      Description = "Noctalia shell";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f %t/noctalia-wayland-1.sock %t/noctalia-wayland-1.lock %t/noctalia-dmenu-wayland-1.sock";
      ExecStart = "${config.programs.noctalia.package}/bin/noctalia";
      Restart = "on-failure";
      RestartSec = "2s";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
