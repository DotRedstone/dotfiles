# ---
# Module: Boot & Kernel
# Description: Unified bootloader, kernel parameters, and Btrfs rollback logic
# ---

{ pkgs, ... }: {
  # [Kernel]
  # Using latest kernel for better Intel Ultra 7 155H (Meteor Lake) support
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [
    "quiet" "splash" "boot.shell_on_fail" "loglevel=3"
    "rd.systemd.show_status=false" "rd.udev.log_level=3"
    "udev.log_priority=3" "vt.global_cursor_default=0"
  ];

  # [Bootloader]
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
    consoleMode = "max";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  # [Plymouth & Silent Boot]
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.initrd.systemd.enable = true;

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
      mount -t btrfs /dev/disk/by-id/nvme-YMTC_PC300-1TB-D_YMA21T0JA240450BCL-part5 /btrfs_tmp
      if [ -e /btrfs_tmp/@ ]; then
          timestamp=$(date "+%Y-%m-%d_%H:%M:%S")
          mkdir -p /btrfs_tmp/old_roots
          mv /btrfs_tmp/@ /btrfs_tmp/old_roots/$timestamp
      fi
      btrfs subvolume snapshot /btrfs_tmp/@blank /btrfs_tmp/@
      umount /btrfs_tmp
    '';
  };
}
