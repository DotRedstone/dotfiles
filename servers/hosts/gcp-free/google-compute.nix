# ---
# Module: GCP Free Platform
# Description: Google Compute Engine guest integration and UEFI boot settings
# Scope: Host
# Notes:
# - OS Login stays disabled so repository-managed SSH keys remain authoritative.
# - The host firewall overrides the Google image module's permissive default.
# ---

{ lib, modulesPath, ... }: {
  imports = [ (modulesPath + "/virtualisation/google-compute-config.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";

  security.googleOsLogin.enable = lib.mkForce false;
  networking.firewall.enable = lib.mkForce true;
  boot.growPartition = lib.mkForce false;

  fileSystems = {
    "/".device = lib.mkForce "/dev/disk/by-partlabel/disk-system-root";
    "/boot".device = lib.mkForce "/dev/disk/by-partlabel/disk-system-ESP";
  };

  boot.loader = {
    systemd-boot.enable = false;
    efi.canTouchEfiVariables = false;
    grub = {
      enable = true;
      device = lib.mkForce "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };
}
