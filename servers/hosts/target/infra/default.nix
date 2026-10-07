# ---
# Module: Target Infrastructure Switchboard
# Description: Unified entry point for EasyTier relay and isolated backups
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./easytier.nix
    ./backup.nix
  ];
}
