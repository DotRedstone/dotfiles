# ---
# Module: Conduit Infrastructure Switchboard
# Description: Unified entry point for Conduit backups and monitoring
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./backup.nix
    ./monitoring.nix
  ];
}
