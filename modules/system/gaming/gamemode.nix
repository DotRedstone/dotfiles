# ---
# Module: Gaming - GameMode
# Description: Feral GameMode for CPU scaling and performance prioritization
# Scope: System
# ---

{ pkgs, ... }: {
  programs.gamemode = {
    enable = true;
    settings = {
      custom = {
        start = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
        end = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced";
      };
    };
  };
}
