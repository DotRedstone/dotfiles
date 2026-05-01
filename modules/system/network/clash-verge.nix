# ---
# Module: Network - Clash Verge
# Description: Clash Verge Rev proxy client with TUN mode support
# Scope: System
# ---

{ ... }: {
  # [Proxy Client - Clash Verge Rev]
  # NixOS official module handles TUN privileges automatically
  programs.clash-verge = {
    enable = true;
    tunMode = true;
    autoStart = false;
  };
}
