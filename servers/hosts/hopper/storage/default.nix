# ---
# Module: Hopper Storage Switchboard
# Description: Unified entry point for OpenList and RustFS file storage services
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./openlist.nix
    ./rustfs.nix
  ];
}
