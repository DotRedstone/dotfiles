# ---
# Module: Network - Clash Verge
# Description: Clash Verge Rev proxy client with TUN mode support
# Scope: System
# ---

{ ... }: {
  # [Proxy Client - Clash Verge Rev]
  # Kept as disabled fallback only; active proxy client is FlClash.
  programs.clash-verge = {
    enable = false;
    tunMode = true;
    autoStart = false;
  };
}
