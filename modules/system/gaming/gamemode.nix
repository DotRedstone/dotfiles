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
        start = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance || /run/current-system/sw/bin/xiaomi-fan-mode performance";
        end = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced || /run/current-system/sw/bin/xiaomi-fan-mode balanced";
      };
    };
  };
}
