# ---
# Module: Monitoring Tools
# Description: Resource monitoring utilities for CPU, memory, GPU, Vulkan, and OpenGL
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    resources
    mission-center
    intel-gpu-tools
    vulkan-tools
    mesa-demos
  ];
}
