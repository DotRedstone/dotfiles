# ---
# Module: Proxy Preferred Probe
# Description: Verify candidate CDN addresses through a restricted HTTPS probe service
# Scope: System
# Notes:
# - Keep disabled until the source CIDRs, two origin IDs, and private TLS route are reviewed.
# - The encrypted environment file carries both HMAC keys, allowed CIDRs, and origin secrets.
# ---

{ config, lib, pkgs, ... }:

let
  cfg = config.dot.services.proxyPreferredProbe;
in
{
  options.dot.services.proxyPreferredProbe = {
    enable = lib.mkEnableOption "the isolated preferred candidate probe";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Pinned edge-proxy-worker source package containing probe/server.mjs.";
    };
    listenHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Probe HTTPS listener; public exposure needs a separately reviewed route.";
    };
    listenPort = lib.mkOption { type = lib.types.port; default = 18444; };
    tlsCertificateFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime TLS certificate path; null uses the SOPS certificate.";
    };
    tlsKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime TLS private key path; null uses the SOPS key.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = cfg.package != null; message = "preferred probe needs pinned Worker source"; }
      { assertion = cfg.listenHost == "127.0.0.1" || cfg.listenHost == "::1";
        message = "preferred probe must stay on loopback until a separate TLS route is reviewed"; }
      { assertion = (cfg.tlsCertificateFile == null) == (cfg.tlsKeyFile == null);
        message = "preferred probe TLS certificate and key paths must be set together"; }
    ];

    sops.secrets."proxy/probe_env" = {
      owner = "root";
      mode = "0400";
      restartUnits = [ "proxy-preferred-probe.service" ];
    };
    sops.secrets."proxy/probe_tls_cert" = lib.mkIf (cfg.tlsCertificateFile == null) {
      owner = "root";
      mode = "0400";
      restartUnits = [ "proxy-preferred-probe.service" ];
    };
    sops.secrets."proxy/probe_tls_key" = lib.mkIf (cfg.tlsKeyFile == null) {
      owner = "root";
      mode = "0400";
      restartUnits = [ "proxy-preferred-probe.service" ];
    };

    systemd.services.proxy-preferred-probe = {
      description = "Restricted HTTPS probe for CDN candidates";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        EnvironmentFile = config.sops.secrets."proxy/probe_env".path;
        Environment = [
          "PROBE_LISTEN_HOST=${cfg.listenHost}"
          "PROBE_LISTEN_PORT=${toString cfg.listenPort}"
          "PROBE_TLS_CERT_FILE=${if cfg.tlsCertificateFile != null then cfg.tlsCertificateFile else config.sops.secrets."proxy/probe_tls_cert".path}"
          "PROBE_TLS_KEY_FILE=${if cfg.tlsKeyFile != null then cfg.tlsKeyFile else config.sops.secrets."proxy/probe_tls_key".path}"
        ];
        ExecStart = "${pkgs.nodejs}/bin/node ${cfg.package}/probe/server.mjs";
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };
  };
}
