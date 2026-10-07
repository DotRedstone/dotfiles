# ---
# Module: Hopper Infrastructure Switchboard
# Description: Unified entry point for databases, backups, cache, monitoring, and web engine
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./databases.nix
    ./backup.nix
    ./nix-cache.nix
    ./monitoring.nix
    ./nginx.nix
  ];
}
