# ---
# Module: Beacon Host Entry
# Description: Host composition and baseline system profile for headless Mac mini (Apple Silicon)
# Scope: Host
# ---

{ pkgs, ... }:

{
  imports = [
    ./headless.nix
    ./networking.nix
    ./services
  ];

  # [Host Platform]
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  # [User & Nix Settings]
  system.primaryUser = "dot";
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "dot" ];
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
  };

  # [System State]
  system.stateVersion = 5;
}
