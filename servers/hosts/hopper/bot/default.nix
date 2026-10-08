# ---
# Module: Hopper Bot Switchboard
# Description: Unified entry point for NapCatQQ, AstrBot, homework plugin, and Nginx proxy
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./containers.nix
    ./plugin.nix
    ./nginx.nix
  ];
}
