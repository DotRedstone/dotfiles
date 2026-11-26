# ---
# Module: Herdr Runtime
# Description: Agent-native terminal multiplexer and background runtime for coding agents
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = [
    pkgs.herdr
    pkgs.herdr-core
  ];
}
