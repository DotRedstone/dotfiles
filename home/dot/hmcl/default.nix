# ---
# Module: HMCL
# Description: Hello Minecraft! Launcher
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    hmcl
  ];
}
