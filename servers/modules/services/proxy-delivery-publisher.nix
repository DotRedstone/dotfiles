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
  runner = pkgs.runCommand "proxy-delivery-publisher-runner" { } ''
    mkdir -p "$out"
    cp ${../../proxy-deployment/scripts/publish-runner.mjs} "$out/publish-runner.mjs"
    cp ${../../proxy-deployment/scripts/publish-core.mjs} "$out/publish-core.mjs"
  '';
  inputs = pkgs.runCommand "proxy-delivery-publisher-inputs" { } ''
    mkdir -p "$out/catalog/profiles"
    for name in nodes owned-domains; do
      cp ${../../proxy-deployment}/"$name".json "$out/catalog/";
    done
    for name in router desktop mobile; do
      cp ${../../proxy-deployment}/profiles/"$name".json "$out/catalog/profiles/";
    done
    cp ${../../flake.lock} "$out/flake.lock"
  '';
  settings = pkgs.writeText "proxy-delivery-publisher.json" (builtins.toJSON {
    version = 1;
    catalogDir = "${inputs}/catalog";
    compilerSource = "${proxyStack.outPath}";
    compilerRevision = revision;
    flakeLockPath = "${inputs}/flake.lock";
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
      { assertion = cfg.geoSitePath != "" && cfg.geoIpPath != "";
        message = "proxy delivery needs local GeoSite and GeoIP files"; }
    ];

    sops.secrets."proxy/delivery_runtime" = {
      owner = "root";
      mode = "0400";
    };

    systemd.services.proxy-delivery-publish = {
      description = "Publish validated proxy profiles to isolated delivery KV";
      path = [ pkgs.util-linux pkgs.nix ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/run/lock" ];
        NoNewPrivileges = true;
        ExecStart = ''${pkgs.nodejs}/bin/node ${runner}/publish-runner.mjs --config ${settings} --secrets ${config.sops.secrets."proxy/delivery_runtime".path} --apply'';
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
