# ---
# Module: Virtualization
# Description: Docker containers and KVM/QEMU virtualization
# ---

{ pkgs, ... }: {
  # [Docker]
  virtualisation.docker = {
    enable = true;
    # Prevent Docker from taking over iptables to avoid firewall conflicts
    daemon.settings = {
      iptables = false;
    };
  };

  # [KVM / QEMU]
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      runAsRoot = false;
      swtpm.enable = true;
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  # [Management Tools]
  programs.virt-manager.enable = true;
}
