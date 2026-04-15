# ---
# Module: Hardware Services
# Description: Power management, Audio (PipeWire), and Bluetooth
# ---

{ pkgs, ... }: {
  # [Audio]
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # [Bluetooth]
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # [Power Management]
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true; # Meteor Lake thermal control

  # [Hardware Tools]
  environment.systemPackages = with pkgs; [
    brightnessctl # Brightness (Fn keys)
    pamixer       # Volume CLI
    pulsemixer    # Volume TUI
    acpi          # Battery check
  ];
}
