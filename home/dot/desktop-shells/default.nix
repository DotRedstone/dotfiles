# ---
# Module: Desktop Shells Switchboard
# Description: Unified entry point for optional Wayland desktop shells and switcher
# Scope: Home Manager
# ---

{ ... }: {
  imports = [
    ./dms.nix
    ./dms-color-scheme.nix
    ./clavis.nix
    ./switcher.nix
  ];
}
