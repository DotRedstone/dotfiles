# ---
# Module: Network - Firewall
# Description: System firewall rules and trusted interfaces
# Scope: System
# ---

{ ... }: {
  # [Firewall]
  # Trust the TUN interface created by Clash Verge
  networking.firewall.trustedInterfaces = [ "tun0" "Meta" ];
}
