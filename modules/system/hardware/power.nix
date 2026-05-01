# ---
# Module: Hardware - Power
# Description: Power profiles, thermal control, and battery monitoring
# Scope: System
# ---

{ ... }: {
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true; # Meteor Lake thermal control
}
