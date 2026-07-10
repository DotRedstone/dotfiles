# ---
# Module: Codex Desktop
# Description: ChatGPT Desktop unofficial client
# Scope: Home Manager
# ---

{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.codex-desktop-linux.packages.${pkgs.system}.default
  ];
}
