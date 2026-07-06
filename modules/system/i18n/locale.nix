# ---
# Module: System Locale
# Description: Configuration for time zones, default locale, and extra locale settings
# Scope: System
# ---

{ pkgs, ... }: {
  time.timeZone = "Asia/Shanghai";
  time.hardwareClockInLocalTime = true;
  networking.timeServers = [
    "ntp.aliyun.com"
    "ntp.tencent.com"
    "cn.pool.ntp.org"
    "time.cloudflare.com"
  ];

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

  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };
  i18n.supportedLocales = [ "zh_CN.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
}
