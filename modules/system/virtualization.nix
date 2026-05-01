# ---
# Module: Virtualization
# Description: Docker containers and KVM/QEMU virtualization services
# Scope: System
# ---

{ pkgs, ... }: {
  # [Docker]
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false; # Don't start on boot to save memory
    daemon.settings = {
      iptables = false;
    };
  };

  # [KVM / QEMU]
  virtualisation.libvirtd = {
    enable = true;
    # Will be socket-activated or started manually via virt-manager
    qemu = {
      runAsRoot = false;
      swtpm.enable = true;
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  systemd.services.libvirtd.serviceConfig.LoadCredential = "";

  # [Management Tools]
  programs.virt-manager.enable = true;

}
