# ---
# Module: Pi Coding Agent
# Description: Pi terminal coding agent CLI
# Scope: Home Manager
# ---

{ lib, pkgs, ... }: {
  home.packages = [
    pkgs.pi-coding-agent
  ];

  # herdr 集成时会检查 ~/.pi/agent/extensions 是否存在
  home.activation.ensurePiExtensionsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.pi/agent/extensions"
  '';
}
