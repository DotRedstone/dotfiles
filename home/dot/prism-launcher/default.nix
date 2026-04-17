# ---
# Module: Prism Launcher
# Description: Minecraft launcher with Java runtimes
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    prismlauncher
  ];
}
