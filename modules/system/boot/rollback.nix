# ---
# Module: Boot - Rollback
# Description: Initrd service for Btrfs stateless root rollback
# Scope: System
# Notes:
# - Rollback script depends on /persist and / (Btrfs subvolumes)
# - Hardcoded UUID must match the root Btrfs partition
# ---

{ pkgs, ... }: {
  # [Btrfs Impermanence Rollback]
  boot.initrd.supportedFilesystems = [ "btrfs" ];
  boot.initrd.systemd.services.warden-rollback = {
    description = "Warden Btrfs Impermanence Rollback";
    wantedBy = [ "initrd.target" ];
    after = [ "initrd-root-device.target" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ coreutils util-linux btrfs-progs ];
    script = ''
      mkdir -p /btrfs_tmp
      mount -t btrfs /dev/disk/by-uuid/c8f96d2d-8a97-4cbb-8a17-bb9de844060b /btrfs_tmp
      if [ -e /btrfs_tmp/@ ]; then
          timestamp=$(date "+%Y-%m-%d_%H:%M:%S")
          mkdir -p /btrfs_tmp/old_roots
          mv /btrfs_tmp/@ /btrfs_tmp/old_roots/$timestamp
      fi
      btrfs subvolume snapshot /btrfs_tmp/@blank /btrfs_tmp/@

      # [Snapshot Maintenance]
      # Keep last 15 old_roots as safety net for forgotten persistence paths
      if [ -d /btrfs_tmp/old_roots ]; then
          snapshot_count=$(ls -1 /btrfs_tmp/old_roots | wc -l)
          if [ "$snapshot_count" -gt 15 ]; then
              ls -1 /btrfs_tmp/old_roots | sort | head -n -15 | while read -r name; do
                  btrfs subvolume delete "/btrfs_tmp/old_roots/$name"
              done
          fi
      fi

      umount /btrfs_tmp
    '';
  };
}
