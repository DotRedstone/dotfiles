# ---
# Module: Persistence Switchboard
# Description: Unified entry point for atomized persistence modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./base.nix
    ./system-paths.nix
    ./user-core.nix
    ./user-apps.nix
    ./user-dev.nix
    ./user-virtualization.nix
  ];
}
