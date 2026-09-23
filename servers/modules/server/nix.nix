# ---
# Module: Server Nix
# Description: Flake support and conservative automatic Nix store maintenance
# Scope: System
# ---

{ ... }: {
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;

      # Hopper relays cache.nixos.org through its Singapore disk cache. The upstream
      # signing key is Nix's built-in cache.nixos.org key, so no new trust root exists.
      # A short timeout guarantees direct official-cache fallback if Hopper is offline.
      extra-substituters = [ "https://nix-cache.bdot.in?priority=20" ];
      connect-timeout = 5;
      fallback = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}
