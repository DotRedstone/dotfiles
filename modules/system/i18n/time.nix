# ---
# Module: System Time
# Description: Configuration for time zones, NTP servers, and hardware clock
# Scope: System
# ---

{ pkgs, ... }: {
  time.timeZone = "Asia/Shanghai";
  time.hardwareClockInLocalTime = true;

  # [Network]
  networking.timeServers = [
    "ntp.aliyun.com"
    "ntp.tencent.com"
    "cn.pool.ntp.org"
    "time.cloudflare.com"
  ];

  # [Service]
  systemd.services.local-rtc-to-system-clock = {
    description = "Set system clock from local-time hardware clock";
    wantedBy = [ "sysinit.target" ];
    before = [ "systemd-timesyncd.service" "time-sync.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/hwclock --hctosys --localtime";
    };
  };
}
