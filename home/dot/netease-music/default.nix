# ---
# Module: NetEase Music Switchboard
# Description: Unified entry point for NetEase Cloud Music GUI and TUI clients
# Scope: Home Manager
# ---

{ ... }: {
  imports = [
    ./gtk.nix
    ./tui.nix
  ];
}
