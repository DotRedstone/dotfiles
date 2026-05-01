# ---
# Module: Network Switchboard
# Description: Unified entry point for NetworkManager, Proxy, and Firewall
# Scope: System
# ---

{ ... }: {
  imports = [
    ./networkmanager.nix
    ./clash-verge.nix
    ./firewall.nix
  ];
}
