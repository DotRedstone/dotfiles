# ---
# Module: Host Configuration
# Description: Main host profile for Warden (Redmi Book Pro 16 2024)
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
  # Graphics patch for Intel Ultra 7 155H (Arc GPU)
  boot.kernelParams = [ "xe.force_probe=7d85" ];

  # [Storage]
  # Swap device defined here; mount points are in mounts.nix
  swapDevices = [ {
    device = "/swap/swapfile";
    size = 33 * 1024;
  } ];

  system.stateVersion = "24.11";
}
