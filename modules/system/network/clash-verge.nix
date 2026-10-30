# ---
# Module: Network - Clash Verge
# Description: Clash Verge Rev proxy client with TUN mode support
# Scope: System
# ---

{ ... }: {
  # [Proxy Client - Clash Verge Rev]
  # Disabled legacy fallback; active proxy is managed by Mihomo.
  programs.clash-verge = {
    enable = false;
    tunMode = true;
    autoStart = false;
  };
}
