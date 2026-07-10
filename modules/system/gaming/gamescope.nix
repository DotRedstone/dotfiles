# ---
# Module: Gaming - Gamescope
# Description: Gamescope micro-compositor for resolution scaling and frame pacing (essential for Intel Arc iGPU)
# Scope: System
# ---

{ ... }: {
  programs.gamescope = {
    enable = true;
  };
}
