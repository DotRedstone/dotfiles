# ---
# Module: Niri Packages
# Description: Core utilities for screenshot, clipboard, and desktop shell
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    # [Core]
    xwayland-satellite

    # [Screenshot & Clipboard]
    cliphist
    wl-clipboard
    grim
    slurp
    swappy

    # [Desktop Services]
    awww    # Wallpaper daemon
    fuzzel  # Backup launcher
  ];
}
