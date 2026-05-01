# ---
# Module: Nix - Nixpkgs
# Description: Nixpkgs global configuration and licensing policies
# Scope: System
# ---

{ ... }: {
  # [Licensing]
  nixpkgs.config.allowUnfree = true;
}
