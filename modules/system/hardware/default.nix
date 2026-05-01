# ---
# Module: Hardware Switchboard
# Description: Unified entry point for atomized hardware service modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./power.nix
    ./tools.nix
  ];
}
