# ---
# Module: macOS Home Configuration
# Description: Home-manager entry point for Darwin (Beacon)
# ---

{ config, pkgs, ... }: {
  home.username = "dot";
  home.homeDirectory = "/Users/dot";
  home.stateVersion = "24.05";

  # [Shared CLI & Dev Modules]
  imports = [
    ./cli-tools/default.nix
    ./dev/default.nix
    ./fish/default.nix
    ./kitty/default.nix
    ./neovim/default.nix
    ./starship/default.nix
    ./wezterm/default.nix
    ./yazi/default.nix
    ./zellij/default.nix
  ];

  # [macOS Specific Packages]
  home.packages = with pkgs; [
    raycast
  ];

  programs.home-manager.enable = true;
}
