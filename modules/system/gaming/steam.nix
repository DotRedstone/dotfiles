# ---
# Module: Gaming - Steam
# Description: Steam client, Proton support, and optional network permissions
# Scope: System
# ---

{ ... }: {
  programs.steam = {
    enable = true;

    # Open only if needed. Keep conservative by default.
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = false;
  };
}
