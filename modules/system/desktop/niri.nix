# ---
# Module: Desktop - Niri
# Description: Niri compositor system-level enablement
# Scope: System
# ---

{ pkgs, inputs, ... }:

let
  niriPackage = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;
in
{
  programs.niri = {
    enable = true;
    package = niriPackage;
  };

  services.displayManager.defaultSession = "niri";

  # Keep the user service resolvable from the system profile even when the
  # package-provided unit is not picked up correctly by the user manager.
  systemd.user.services.niri = {
    description = "A scrollable-tiling Wayland compositor";
    bindsTo = [ "graphical-session.target" ];
    before = [
      "graphical-session.target"
      "xdg-desktop-autostart.target"
    ];
    wants = [
      "graphical-session-pre.target"
      "xdg-desktop-autostart.target"
    ];
    after = [ "graphical-session-pre.target" ];
    serviceConfig = {
      Slice = "session.slice";
      Type = "notify";
      ExecStart = "${niriPackage}/bin/niri --session";
    };
  };
}
