# ---
# Module: Nix Settings
# Description: Global Nix package manager and Flake configuration
# ---

{ ... }: {
  nix.settings = {
    # [Features]
    experimental-features = [ "nix-command" "flakes" ];
    
    # [Optimization]
    # Automatically hard-link identical files in the store to save Btrfs space
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  # [Licensing]
  nixpkgs.config.allowUnfree = true;
}
