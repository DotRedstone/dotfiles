# ---
# Module: Niri Output Fallback
# Description: Move workspaces off a powered-off external monitor and restore them when it returns
# Scope: Home Manager
# ---
# Notes:
# - Some monitors retain HDMI hotplug while powered off, so Niri cannot observe that state as a disconnect.
# - DDC failures only count while Niri drives HDMI (dpms On); a monitor blanked by Niri also stops answering DDC.
# - The HDMI output stays enabled so a monitor powered on again receives a signal and answers DDC.
# - Detection and workspace logic live in output-fallback.py.

{ pkgs, ... }:
let
  niri-output-fallback = pkgs.writeShellScriptBin "niri-output-fallback" ''
    export NIRI_OUTPUT_FALLBACK_DDCUTIL=${pkgs.ddcutil}/bin/ddcutil
    exec ${pkgs.python3}/bin/python3 ${./output-fallback.py} "$@"
  '';
in
{
  home.packages = [ niri-output-fallback ];

  systemd.user.services.niri-output-fallback = {
    Unit = {
      Description = "Move Niri workspaces off a powered-off external monitor and restore them";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${niri-output-fallback}/bin/niri-output-fallback";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
