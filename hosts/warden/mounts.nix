# ---
# Module: Storage Mounts
# Description: Btrfs subvolume layout and mount options for Warden
# ---

{ lib, ... }:
let
  ssd = "/dev/disk/by-uuid/c8f96d2d-8a97-4cbb-8a17-bb9de844060b";
  efi = "/dev/disk/by-uuid/624B-904B";
  btrfsOptions = [ "compress=zstd" "noatime" ];
in {
  # [Btrfs Subvolumes]
  fileSystems."/" = lib.mkForce {
    device = ssd;
    fsType = "btrfs";
    options = [ "subvol=@" ] ++ btrfsOptions;
  };

  fileSystems."/home" = lib.mkForce {
    device = ssd;
    fsType = "btrfs";
    options = [ "subvol=@home" ] ++ btrfsOptions;
    neededForBoot = true; # Must be true for early user login
  };

  fileSystems."/nix" = lib.mkForce {
    device = ssd;
    fsType = "btrfs";
    options = [ "subvol=@nix" ] ++ btrfsOptions;
  };

  fileSystems."/persist" = lib.mkForce {
    device = ssd;
    fsType = "btrfs";
    options = [ "subvol=@persist" ] ++ btrfsOptions; # Must NOT include 'ro'
    neededForBoot = true; # Critical for Impermanence: must be true
  };

  fileSystems."/var/log" = lib.mkForce {
    device = ssd;
    fsType = "btrfs";
    options = [ "subvol=@log" ] ++ btrfsOptions;
    neededForBoot = true;
  };

  # [Special Subvolumes]
  fileSystems."/swap" = lib.mkForce {
    device = ssd;
    fsType = "btrfs";
    options = [ "subvol=@swap" "noatime" ];
  };

  # [EFI Partition]
  fileSystems."/boot" = lib.mkForce {
    device = efi;
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };
}
