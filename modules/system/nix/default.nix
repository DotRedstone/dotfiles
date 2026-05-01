# ---
# Module: Nix Switchboard
# Description: Unified entry point for Nix settings, GC, and nixpkgs configuration
# Scope: System
# ---

{ ... }: {
  imports = [
    ./settings.nix
    ./tools.nix
    ./gc.nix
    ./nixpkgs.nix
  ];
}
