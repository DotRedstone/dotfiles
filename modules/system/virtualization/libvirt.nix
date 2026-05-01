# ---
# Module: Virtualization - Libvirt
# Description: QEMU/KVM hypervisor configuration with swtpm and virtiofs support
# Scope: System
# ---

{ pkgs, ... }: {
  virtualisation.libvirtd = {
    enable = true;
    # Will be socket-activated or started manually via virt-manager
    qemu = {
      runAsRoot = false;
      swtpm.enable = true;
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  # Clear LoadCredential override to avoid potential startup issues with custom certs
  systemd.services.libvirtd.serviceConfig.LoadCredential = "";
}
