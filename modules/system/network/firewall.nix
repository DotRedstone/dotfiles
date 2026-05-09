# ---
# Module: Network - Firewall
# Description: System firewall rules and trusted interfaces
# Scope: System
# ---

{ ... }: {
  # [Firewall]
  # Trust TUN interfaces created by local Clash-compatible proxy clients.
  networking.firewall.trustedInterfaces = [ "FlClash" "tun0" "Meta" ];
}
