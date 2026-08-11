# ---
# Module: Video Editing
# Description: Simple desktop video editors for casual cutting and exporting
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    shotcut
    losslesscut-bin
  ];
}
