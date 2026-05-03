# ---
# Module: Chrome Switchboard
# Description: Unified entry point for Chrome package, flags, and UI tweaks
# Scope: Home Manager
# ---

{ ... }: {
  imports = [
    ./package.nix
    ./flags.nix
    ./vertical-tabs.nix
    ./theme.nix
  ];
}
