# ---
# Module: Target Hardware
# Description: QEMU disk, initrd, and platform settings recovered from the running host
# Scope: Host
# ---

{ lib, modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "sr_mod"
    "virtio_blk"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/d384b237-bd6a-4334-8757-4837eab1d4a9";
    fsType = "ext4";
  };

  # The running Tencent VM is BIOS-booted from the MBR disk, not EFI.
  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/vda" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
