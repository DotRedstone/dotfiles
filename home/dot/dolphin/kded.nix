# ---
# Module: KDE Daemon (kded6)
# Description: Run kded6 for Dolphin's solid device discovery on non-Plasma sessions
# Scope: Home Manager
# Notes:
# - Without kded6, Dolphin's Places panel does not auto-refresh removable devices
#   on Niri (no Plasma session provides the solid device manager).
# ---
{ pkgs, ... }:
{
  systemd.user.services.kded6 = {
    Unit = {
      Description = "KDE Daemon 6 (solid device discovery)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.kded}/bin/kded6";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
