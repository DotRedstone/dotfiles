# ---
# Module: Server Switchboard
# Description: Unified entry point for the minimal shared server modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./base.nix
    ./networking.nix
    ./nix.nix
    ./sshd.nix
    ./tcp-bbr.nix
    ./users.nix
  ];
}
