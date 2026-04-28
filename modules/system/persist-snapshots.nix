# ---
# Module: Persist Snapshots
# Description: Daily Btrfs snapshots of @persist subvolume for data protection
# ---

{ pkgs, ... }: {
  # [Persist Backup Service]
  systemd.services.persist-snapshot = {
    description = "Snapshot @persist subvolume for data recovery";
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ coreutils util-linux btrfs-progs ];
    script = ''
      set -euo pipefail
      trap 'umount /btrfs_tmp 2>/dev/null || true' EXIT

      mkdir -p /btrfs_tmp
      mount -t btrfs /dev/disk/by-uuid/c8f96d2d-8a97-4cbb-8a17-bb9de844060b /btrfs_tmp

      timestamp=$(date "+%Y-%m-%d_%H:%M:%S")
      mkdir -p /btrfs_tmp/persist_snapshots
      btrfs subvolume snapshot -r /btrfs_tmp/@persist "/btrfs_tmp/persist_snapshots/$timestamp"

      # Keep only the last 30 snapshots
      snapshot_count=$(ls -1 /btrfs_tmp/persist_snapshots | wc -l)
      if [ "$snapshot_count" -gt 30 ]; then
          ls -1 /btrfs_tmp/persist_snapshots | sort | head -n -30 | while read -r name; do
              btrfs property set -ts "/btrfs_tmp/persist_snapshots/$name" ro false 2>/dev/null || true
              btrfs subvolume delete "/btrfs_tmp/persist_snapshots/$name"
          done
      fi
    '';
  };

  # [Daily Timer]
  systemd.timers.persist-snapshot = {
    description = "Daily @persist snapshot timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
