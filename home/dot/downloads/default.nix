# ---
# Module: Downloads
# Description: Modern, high-speed downloader for Linux (Gopeed)
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [ gopeed ];
}
