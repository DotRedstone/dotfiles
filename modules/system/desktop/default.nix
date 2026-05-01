# ---
# Module: Desktop Switchboard
# Description: Unified entry point for atomized desktop environment modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./niri.nix
    ./sddm.nix
    ./sddm-numlock.nix
    ./graphics.nix
    ./portals.nix
    ./services.nix
    ./polkit.nix
    ./environment.nix
  ];
}
