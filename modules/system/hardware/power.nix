# ---
# Module: Hardware - Power
# Description: Power profiles, thermal control, and battery monitoring
# Scope: System
# ---

{ ... }: {
  # 低电量时提前休眠：休眠镜像约 12 GB，电池健康度约 80%，默认 2% 的余量不足以
  # 写完镜像，曾因写入中途断电导致下次启动找不到镜像、会话丢失。
  # HybridSleep 已在 systemd-sleep 中禁用，此处直接使用 Hibernate。
  services.upower = {
    enable = true;
    percentageLow = 20;
    percentageCritical = 10;
    percentageAction = 6;
    criticalPowerAction = "Hibernate";
  };
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true; # Meteor Lake thermal control

  # Hide the buggy bitland-mifs-wmi ACPI platform_profile sysfs from
  # power-profiles-daemon so it reliably uses the native intel_pstate driver.
  systemd.services.power-profiles-daemon.serviceConfig.InaccessiblePaths = [
    "-/sys/firmware/acpi/platform_profile"
    "-/sys/firmware/acpi/platform_profile_choices"
  ];
}
