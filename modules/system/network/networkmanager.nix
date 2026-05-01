# ---
# Module: Network - NetworkManager
# Description: NetworkManager enablement for wireless and wired connections
# Scope: System
# ---

{ ... }: {
  networking.networkmanager.enable = true;
}
