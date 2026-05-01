# ---
# Module: Users Switchboard
# Description: Unified entry point for atomized user and shell modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./accounts.nix
    ./shell.nix
    ./core-tools.nix
  ];
}
