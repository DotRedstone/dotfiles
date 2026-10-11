# ---
# Module: Network - Firewall
# Description: System firewall rules and trusted interfaces
# Scope: System
# ---

{ ... }: {
  # [Firewall]
  # Trust TUN interfaces only when a Mihomo profile explicitly enables one.
  networking.firewall.trustedInterfaces = [ "mihomo" "Mihomo" "tun0" "Meta" ];
}
