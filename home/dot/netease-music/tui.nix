# ---
# Module: NetEase Cloud Music TUI
# Description: Terminal UI client for NetEase Cloud Music (go-musicfox)
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = [
    pkgs.go-musicfox
  ];
}
