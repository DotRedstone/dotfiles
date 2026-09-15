# ---
# Module: Hopper OCI Platform
# Description: AArch64 KVM, virtio, UEFI, and Oracle serial-console support
# Scope: Host
# ---

{ lib, modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  nixpkgs.hostPlatform = "aarch64-linux";

  boot = {
    growPartition = lib.mkForce false;
    initrd.availableKernelModules = [
      "virtio_blk"
      "virtio_net"
      "virtio_pci"
      "virtio_scsi"
    ];
    loader = {
      timeout = 1;
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  systemd.services."serial-getty@ttyAMA0".enable = true;
}
