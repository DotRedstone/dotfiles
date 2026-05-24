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
}
