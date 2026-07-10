# ---
# Module: Warden Host Entry
# Description: Main host profile for Warden (Redmi Book Pro 16 2024)
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./mounts.nix
    ../../modules/system
  ];

  # [Identity]
  networking.hostName = "warden";

  # [Boot]
  # Graphics patch for Intel Ultra 7 155H (Arc GPU) - Using i915 for stable sleep/suspend
  boot.kernelParams = [ "i915.force_probe=7d85" ];

  # [Storage]
  # Swap device defined here; mount points are in mounts.nix
  swapDevices = [ {
    device = "/swap/swapfile";
    size = 33 * 1024;
  } ];

  system.stateVersion = "24.11";
}
