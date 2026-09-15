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
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}
