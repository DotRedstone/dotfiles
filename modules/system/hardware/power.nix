# ---
# Module: Hardware - Power
# Description: Power profiles, thermal control, and battery monitoring
# Scope: System
# ---

{ ... }: {
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true; # Meteor Lake thermal control

  # Hide the buggy bitland-mifs-wmi ACPI platform_profile sysfs from
  # power-profiles-daemon so it reliably uses the native intel_pstate driver.
  systemd.services.power-profiles-daemon.serviceConfig.InaccessiblePaths = [
    "-/sys/firmware/acpi/platform_profile"
    "-/sys/firmware/acpi/platform_profile_choices"
  ];
}
