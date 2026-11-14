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
      # Root-owned Mihomo config and provider cache; it contains private URLs.
      "/var/lib/mihomo"
      # UniVPN client state, certificate cache, and sysconfig
      "/var/lib/univpn"
      # UniVPN 以 root 运行（pkexec 提权建 TUN），UserPath=/root，UI 主程序把
      # sysconfig.ini 与登录状态写进 /root/UniVPN（而非 dot 的 ~/UniVPN 或
      # /var/lib/univpn）。/root 默认不持久化，重启后登录状态丢失。
      "/root/UniVPN"
    ];
  };
}
