# ---
# Module: Network Switchboard
# Description: Unified entry point for NetworkManager, Proxy, and Firewall
# Scope: System
# ---

{ ... }: {
  imports = [
    ./networkmanager.nix
    ./flclash.nix
    ./firewall.nix
    ./easytier.nix
  ];
}
