# ---
# Module: Virtualization - Libvirt
# Description: QEMU/KVM hypervisor configuration with swtpm and virtiofs support
# Scope: System
# ---

{ config, pkgs, ... }:
let
  defaultNetworkXml = pkgs.writeText "libvirt-default-network.xml" ''
    <network>
      <name>default</name>
      <bridge name='virbr0'/>
      <forward mode='nat'/>
      <ip address='192.168.122.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.122.2' end='192.168.122.254'/>
        </dhcp>
      </ip>
    </network>
  '';
in {
  virtualisation.libvirtd = {
    enable = true;
    # Will be socket-activated or started manually via virt-manager
    qemu = {
      runAsRoot = false;
      swtpm.enable = true;
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  networking.firewall.trustedInterfaces = [ "virbr0" ];

  systemd.services.libvirt-default-network = {
    description = "Ensure libvirt default NAT network is active";
    after = [ "libvirtd.service" ];
    requires = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      virsh="${config.virtualisation.libvirtd.package}/bin/virsh"

      if ! "$virsh" -c qemu:///system net-info default >/dev/null 2>&1; then
        "$virsh" -c qemu:///system net-define ${defaultNetworkXml}
      fi

      "$virsh" -c qemu:///system net-autostart default

      if ! "$virsh" -c qemu:///system net-info default | grep -q '^Active: *yes'; then
        "$virsh" -c qemu:///system net-start default
      fi
    '';
  };

  # Clear LoadCredential override to avoid potential startup issues with custom certs
  systemd.services.libvirtd.serviceConfig.LoadCredential = "";
}
