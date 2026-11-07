# ---
# Module: Boot - Plymouth
# Description: Visual boot splash and silent boot configuration
# Scope: System
# ---

{ ... }: {
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 0;
}
