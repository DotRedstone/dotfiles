# ---
# Module: App - LM Studio
# Description: Local LLM runner and GUI
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = [
    pkgs.lmstudio
  ];
}
