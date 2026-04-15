# ---
# Module: Nautilus Packages
# Description: Core binary and essential desktop integration tools
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    # [Core]
    nautilus

    # [Preview & Quick Look]
    sushi   # macOS-style spacebar preview
    loupe   # Modern MD3 image viewer
    evince  # Document and PDF viewer
  ];
}
