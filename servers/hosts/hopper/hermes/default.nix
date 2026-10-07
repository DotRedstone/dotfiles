# ---
# Module: Hopper Hermes Switchboard
# Description: Unified entry point for Hermes agent service, secrets, and workspace
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./secrets.nix
    ./workspace.nix
    ./service.nix
  ];
}
