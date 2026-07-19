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
  boot.resumeDevice = "/dev/disk/by-uuid/c8f96d2d-8a97-4cbb-8a17-bb9de844060b";
  boot.kernelParams = [
    "i915.force_probe=7d85"
    "i915.enable_psr=0"
    "i915.enable_dc=0"
    "resume_offset=1696632"
  ];

  # [Power]
  # macOS/Windows-like behavior: power key and lid close enter sleep; power-menu
  # "shutdown" is handled as hibernation in Noctalia so the session can return.
  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
    HandlePowerKeyLongPress = "poweroff";
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "suspend";
  };

  systemd.sleep.settings.Sleep = {
    AllowSuspend = true;
    AllowHibernation = true;
    AllowHybridSleep = true;
    AllowSuspendThenHibernate = true;
  };

  # [Storage]
  # Swap device defined here; mount points are in mounts.nix
  swapDevices = [
    {
      device = "/swap/swapfile";
    }
  ];

  system.stateVersion = "24.11";
}
