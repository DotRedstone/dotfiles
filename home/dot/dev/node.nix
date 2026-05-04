# ---
# Module: Node.js Ecosystem
# Description: Node runtime and JS toolchain required by local script collectors
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    nodejs
    pnpm
    gh
  ];
}
