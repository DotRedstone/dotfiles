# ---
# Module: Network Switchboard
# Description: Unified entry point for NetworkManager, Mihomo, and firewall modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./networkmanager.nix
    ./mihomo.nix
    ./mihomo-profiles.nix
    ./mihomo-lifecycle.nix
    ./firewall.nix
    ./easytier.nix
    ./todesk.nix
    ./sshd.nix
  ];
}
