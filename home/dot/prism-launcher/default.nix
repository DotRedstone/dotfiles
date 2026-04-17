# ---
# Module: Prism Launcher
# Description: Minecraft launcher with Java runtimes
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    prism-launcher
    jdk8
    jdk17
    jdk21
  ];
}
