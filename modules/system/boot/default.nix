# ---
# Module: Boot Switchboard
# Description: Unified entry point for atomized boot and kernel modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./kernel.nix
    ./loader.nix
    ./plymouth.nix
    ./rollback.nix
  ];
}
