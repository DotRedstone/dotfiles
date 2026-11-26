# ---
# Module: WSL Shell Switchboard
# Description: Entry point for interactive shell, prompt, multiplexer, and direnv modules
# Scope: Home Manager
# ---

{ ... }: {
  imports = [
    ./fish.nix
    ./starship.nix
    ./zellij.nix
    ./direnv.nix
  ];
}
