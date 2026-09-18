# ---
# Module: Input Automation
# Description: Provide the privileged virtual-input daemon used by user-facing automation tools
# Scope: System
# ---
# Notes:
# - Access is limited to the existing input group; the daemon does not expose a network listener.

{ ... }:
{
  programs.ydotool = {
    enable = true;
    group = "input";
  };
}
