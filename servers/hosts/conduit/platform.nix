# ---
# Module: Conduit Platform
# Description: QEMU guest support and BIOS GRUB settings for RackNerd
# Scope: Host
# ---

{ lib, modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    growPartition = lib.mkForce false;
    loader = {
      timeout = 1;
      grub = {
        enable = true;
        configurationLimit = 5;
      };
    };
  };
}
