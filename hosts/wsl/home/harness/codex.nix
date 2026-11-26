# ---
# Module: Codex CLI Harness
# Description: OpenAI Codex CLI coding agent tracked from nixpkgs
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = [
    pkgs.codex
  ];
}
