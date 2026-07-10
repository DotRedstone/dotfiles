# ---
# Module: Gaming - GameMode
# Description: Feral GameMode for CPU scaling and performance prioritization
# Scope: System
# ---

{ ... }: {
  programs.gamemode = {
    enable = true;
  };
}
