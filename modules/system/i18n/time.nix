# ---
# Module: System Time
# Description: Configuration for time zones, NTP servers, and hardware clock
# Scope: System
# ---
# Notes:
# - RTC 存 UTC（hardwareClockInLocalTime = false）。此前设为 true 会让 systemd 把
#   RTC 里的 UTC 值当本地时间读，NTP 同步后系统时钟整体偏差 8 小时。
# - NTP 服务器优先写 IP：本机 DNS 由上游路由器下发 fake-ip（198.18.0.0/16），
#   按域名解析得到的地址在 UDP 123 上并不稳定，直接写 IP 可绕开该问题。
#   两个上游 IP 已实测 3/3 可达且偏差 < 30ms，域名作为 fallback 保留。

{ pkgs, ... }: {
  time.timeZone = "Asia/Shanghai";
  time.hardwareClockInLocalTime = false;

  # [Network]
  networking.timeServers = [
    "185.209.85.222"   # ntp.xtom.com
    "162.159.200.1"    # time.cloudflare.com
    "162.159.200.123"  # time.cloudflare.com
    "ntp.aliyun.com"
    "ntp.tencent.com"
    "cn.pool.ntp.org"
  ];
}
