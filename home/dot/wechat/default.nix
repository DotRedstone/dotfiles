# ---
# Module: WeChat Switchboard
# Description: Unified entry point for WeChat packages, entry, and bridge
# Scope: Home Manager
# ---

{ ... }: {
  imports = [
    ./clipboard-bridge.nix
    ./packages.nix
    ./desktop-entry.nix
    ./notify-bridge.nix
  ];
}
