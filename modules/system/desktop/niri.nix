# ---
# Module: Desktop - Niri
# Description: Niri compositor system-level enablement
# Scope: System
# ---

{ pkgs, inputs, ... }: {
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };

  services.displayManager.defaultSession = "niri";
}
