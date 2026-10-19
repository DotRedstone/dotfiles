# ---
# Module: Network - Firewall
# Description: System firewall rules and trusted interfaces
# Scope: System
# ---

{ ... }: {
  # [Firewall]
  # Trust TUN interfaces only when a Mihomo profile explicitly enables one.
  networking.firewall.trustedInterfaces = [ "mihomo" "Mihomo" "tun0" "Meta" ];

  # [Subnet Trust]
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -s 10.0.0.0/24 -j ACCEPT
    iptables -A nixos-fw -s 10.8.0.0/24 -j ACCEPT
  '';
}
