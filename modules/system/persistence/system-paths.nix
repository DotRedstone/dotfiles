# ---
# Module: Persistence - System Paths
# Description: Critical system directories to persist across reboots
# Scope: System
# ---

{ ... }: {
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/libvirt"
      "/var/lib/systemd"
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/var/lib/docker"
      "/var/lib/AccountsService"
    ];
  };
}
