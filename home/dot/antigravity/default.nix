# ---
# Module: Google Antigravity AI Agent
# Description: AI-powered coding assistant from Google, integrated via flake package
# ---

{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.antigravity-nix.packages.${pkgs.system}.default
  ];
}
