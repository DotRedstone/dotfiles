# ---
# Module: WSL System Switchboard
# Description: Unified entry point for NixOS-WSL system modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./wsl.nix
    ./nix.nix
    ./nix-ld.nix
    ./locale.nix
    ./sshd.nix
  ];
}
