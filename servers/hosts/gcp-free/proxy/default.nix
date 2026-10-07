# ---
# Module: GCP Free Proxy Switchboard
# Description: Unified entry point for GCP proxy gateway and egress quota guard
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./xray.nix
    ./egress-guard.nix
  ];
}
