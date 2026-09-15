# ---
# Module: Native Navidrome
# Description: Native loopback-only Navidrome service with persistent music and metadata
# Scope: System
# ---

{ config, lib, ... }:

let
  cfg = config.dot.services.navidrome;
in
{
  options.dot.services.navidrome.enable = lib.mkEnableOption "the native Navidrome service";

  config = lib.mkIf cfg.enable {
    services.navidrome = {
      enable = true;
      openFirewall = false;
      settings = {
        Address = "127.0.0.1";
        Port = 4533;
        DataFolder = "/var/lib/navidrome";
        MusicFolder = "/var/lib/navidrome/music";
        LogLevel = "info";
        ScanSchedule = "1h";
        SessionTimeout = "24h";
        EnableInsightsCollector = false;
      };
    };
  };
}
