# ---
# Module: Nix Settings
# Description: Global Nix package manager and Flake configuration
# Scope: System
# ---

{ pkgs, ... }: {
  nix.settings = {
    # [Features]
    experimental-features = [ "nix-command" "flakes" ];
    
    # [Optimization]
    # Automatically hard-link identical files in the store to save Btrfs space
    auto-optimise-store = true;
  };

  environment.systemPackages = with pkgs; [
    git
    nh
    nix-output-monitor
    nvd
    sops
    age
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  # [Licensing]
  nixpkgs.config.allowUnfree = true;
}
