# ---
# Module: Hopper Gmail Switchboard
# Description: Unified entry point for Gmail Archiver service and secrets
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./secrets.nix
    ./service.nix
  ];
}
