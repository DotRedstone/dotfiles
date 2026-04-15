# ---
# Module: Nautilus Packages
# Description: Core binary and essential desktop integration tools
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    # [Core]
    nautilus

    # [Preview & Quick Look]
    sushi
    loupe
    evince
    gnome-autoar
    file-roller
  ];
}
