# ---
# Module: WSL CLI Tools Switchboard
# Description: Unified entry point for core, modern, network, and git CLI modules
# Scope: Home Manager
# ---

{ ... }: {
  imports = [
    ./core.nix
    ./modern.nix
    ./network.nix
    ./git.nix
  ];
}
