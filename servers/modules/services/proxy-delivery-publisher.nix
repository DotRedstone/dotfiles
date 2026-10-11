# ---
# Module: Proxy Delivery Publisher
# Description: Periodically publish validated proxy profiles from the locked compiler
# Scope: System
# Notes:
# - Keep disabled until the isolated account and v2 Worker bindings pass runtime checks.
# - The SOPS runtime document must never enter the Nix store.
# ---

{ config, lib, pkgs, proxyStack ? null, ... }:

let
  cfg = config.dot.services.proxyDeliveryPublisher;
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  revision = lock.nodes.proxyStack.locked.rev;
  runner = ../../proxy-deployment/scripts/publish-runner.mjs;
  settings = pkgs.writeText "proxy-delivery-publisher.json" (builtins.toJSON {
    version = 1;
    catalogDir = toString ../../proxy-deployment;
    compilerSource = toString proxyStack.outPath;
    compilerRevision = revision;
    flakeLockPath = toString ../../flake.lock;
    preferredBaseUrl = cfg.preferredBaseUrl;
    maxPoolAgeSeconds = cfg.maxPoolAgeSeconds;
    mihomoBin = "${pkgs.mihomo}/bin/mihomo";
    geoSitePath = cfg.geoSitePath;
    geoIpPath = cfg.geoIpPath;
    lockFile = "/run/lock/proxy-delivery-publish.lock";
  });
in
{
  options.dot.services.proxyDeliveryPublisher = {
    enable = lib.mkEnableOption "the isolated proxy delivery publisher";
    preferredBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "https://preferred.example.test";
      description = "HTTPS address of the new preferred-v2 control Worker.";
    };
    maxPoolAgeSeconds = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "Maximum age of a validated v2 pool before publication stops.";
    };
    geoSitePath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Existing local GeoSite.dat path used only for Mihomo static validation.";
    };
    geoIpPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Existing local geoip.metadb path used only for Mihomo static validation.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = proxyStack != null; message = "proxy delivery needs the locked proxyStack input"; }
      { assertion = lib.hasPrefix "https://" cfg.preferredBaseUrl;
        message = "proxy delivery needs a private HTTPS preferred-v2 endpoint"; }
      { assertion = cfg.geoSitePath != "" && cfg.geoIpPath != "";
        message = "proxy delivery needs local GeoSite and GeoIP files"; }
    ];

    sops.secrets."proxy/delivery_runtime" = {
      owner = "root";
      mode = "0400";
    };

    systemd.services.proxy-delivery-publish = {
      description = "Publish validated proxy profiles to isolated delivery KV";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/run/lock" ];
        NoNewPrivileges = true;
        ExecStart = ''${pkgs.nodejs}/bin/node ${runner} --config ${settings} --secrets ${config.sops.secrets."proxy/delivery_runtime".path} --apply'';
      };
    };

    systemd.timers.proxy-delivery-publish = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
      };
    };
  };
}
