# ---
# Module: Nix - Settings
# Description: Global Nix package manager and Flake configuration
# Scope: System
# ---

{ ... }: {
  nix.settings = {
    # [Features]
    experimental-features = [ "nix-command" "flakes" ];
    
    # [Optimization]
    # Automatically hard-link identical files in the store to save Btrfs space
    auto-optimise-store = true;
  };
}
