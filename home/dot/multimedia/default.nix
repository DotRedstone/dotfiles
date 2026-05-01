# ---
# Module: Multimedia Switchboard
# Description: Audio/Video tools and visualizers
# Scope: Home Manager
# ---

{ ... }: {
  imports = [
    ./cava.nix
    ./mpv.nix
    ./imv.nix
    ./peaclock.nix
  ];
}
