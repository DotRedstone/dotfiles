# ---
# Module: Cursor CLI
# Description: Cursor terminal coding agent CLI (cursor-agent)
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = [
    pkgs.cursor-cli
  ];
}
