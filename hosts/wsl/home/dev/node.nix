# ---
# Module: Node.js & JS Ecosystem
# Description: Node.js, pnpm, bun, and GitHub CLI
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    nodejs
    pnpm
    bun
    gh
  ];
}
