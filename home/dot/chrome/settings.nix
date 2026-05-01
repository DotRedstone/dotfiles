# ---
# Module: Chrome Settings (Deprecated)
# Description: This module has been split into package.nix, flags.nix, and vertical-tabs.nix
# Scope: Home Manager
# ---

{ ... }: {
  imports = [
    ./flags.nix
    ./vertical-tabs.nix
  ];
}
