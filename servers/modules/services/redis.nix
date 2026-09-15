# ---
# Module: Native Redis
# Description: Native loopback-only Redis service with encrypted authentication
# Scope: System
# Notes:
# - The migration rotates the legacy password that was exposed through Docker process arguments.
# ---

{ config, lib, ... }:

let
  cfg = config.dot.services.redis;
in
{
  options.dot.services.redis.enable = lib.mkEnableOption "the native Redis database";

  config = lib.mkIf cfg.enable {
    sops.secrets."redis/password" = {
      owner = "redis";
      group = "redis";
      mode = "0400";
      restartUnits = [ "redis.service" ];
    };

    services.redis.servers."" = {
      enable = true;
      bind = "127.0.0.1";
      port = 6379;
      openFirewall = false;
      requirePassFile = config.sops.secrets."redis/password".path;
      appendOnly = false;
    };
  };
}
