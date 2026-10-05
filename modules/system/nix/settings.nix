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

    # Hopper keeps a bounded on-demand mirror of cache.nixos.org in Singapore.
    # Responses retain the official cache signature; a failed relay falls back quickly.
    extra-substituters = [ "https://nix-cache.bdot.in?priority=20" ];
    connect-timeout = 5;
    fallback = true;

    # [Security]
    # Allow users in the wheel group to specify binary caches
    trusted-users = [ "root" "@wheel" ];
  };
}
