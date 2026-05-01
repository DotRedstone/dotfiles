# ---
# Module: Virtualization - Docker
# Description: Docker daemon configuration with memory-saving boot delay
# Scope: System
# ---

{ ... }: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false; # Don't start on boot to save memory
    daemon.settings = {
      iptables = false;
    };
  };
}
