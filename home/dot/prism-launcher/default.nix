# ---
# Module: Prism Launcher
# Description: Minecraft launcher with Java runtimes
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    prismlauncher
  ];
}
