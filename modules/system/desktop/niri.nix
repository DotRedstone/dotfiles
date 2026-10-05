# ---
# Module: Desktop - Niri
# Description: Niri compositor system-level enablement
# Scope: System
# ---

{ pkgs, inputs, ... }:
{
  programs.niri = {
    enable = true;
    # Upstream niri now ships the SHM (memfd) screencasting fallback and uses
    # libdisplay-info 0.3 directly, so the previous local patch/override is gone.
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };

  services.displayManager.defaultSession = "niri";
}
