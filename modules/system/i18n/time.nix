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
}
