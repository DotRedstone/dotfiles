# ---
# Module: Hardware - Bluetooth
# Description: Bluetooth stack and blueman management service
# Scope: System
# ---

{ ... }: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
}
