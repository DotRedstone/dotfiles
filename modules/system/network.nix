# ---
# Module: Networking
# Description: NetworkManager, proxy client, and firewall rules
# ---

{ pkgs, ... }: {
  # [NetworkManager]
  networking.networkmanager.enable = true;

  # [Proxy Client - Clash Verge Rev]
  # NixOS official module handles TUN privileges automatically
  programs.clash-verge = {
    enable = true;
    tunMode = true;
    autoStart = false;
  };

  # [Firewall]
  # Trust the TUN interface created by Clash Verge
  networking.firewall.trustedInterfaces = [ "tun0" "Meta" ];
}
