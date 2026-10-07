# ---
# Module: GCP Free Infrastructure Switchboard
# Description: Unified entry point for GCP node mesh network and monitoring
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./easytier.nix
    ./monitoring.nix
  ];
}
