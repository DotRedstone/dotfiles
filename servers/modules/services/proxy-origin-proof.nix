# ---
# Module: Proxy Origin Proof
# Description: Serve a private origin identity proof behind the existing CDN TLS host
# Scope: System
# Notes:
# - Keep disabled until the isolated probe and CDN path have passed runtime checks.
# - The client must provide the proof token; Nginx must not inject it for public callers.
# ---

{ config, lib, pkgs, ... }:

let
  cfg = config.dot.services.proxyOriginProof;
in
{
  options.dot.services.proxyOriginProof = {
    enable = lib.mkEnableOption "the isolated origin proof endpoint";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Pinned edge-proxy-worker source package containing origin-proof/server.mjs.";
    };
    serverName = lib.mkOption { type = lib.types.str; default = ""; };
    originId = lib.mkOption { type = lib.types.str; default = ""; };
    port = lib.mkOption { type = lib.types.port; default = 18443; };
    path = lib.mkOption { type = lib.types.str; default = "/proof"; };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = cfg.package != null; message = "origin proof needs pinned Worker source"; }
      { assertion = cfg.serverName != "" && config.dot.services.xrayCdnWebSocket.enable;
        message = "origin proof needs the existing CDN TLS host"; }
      { assertion = cfg.serverName == config.dot.services.xrayCdnWebSocket.serverName;
        message = "origin proof must use the existing CDN TLS host"; }
      { assertion = builtins.match "[a-z][a-z0-9-]*" cfg.originId != null;
        message = "origin proof needs a stable origin ID"; }
      { assertion = builtins.match "/[A-Za-z0-9/_-]+" cfg.path != null;
        message = "origin proof needs a dedicated path"; }
    ];

    sops.secrets."proxy/origin_proof_key" = { owner = "root"; mode = "0400"; };
    sops.secrets."proxy/origin_proof_token" = { owner = "root"; mode = "0400"; };
    sops.templates."proxy-origin-proof.env" = {
      owner = "root";
      mode = "0400";
      content = ''
        ORIGIN_PROOF_KEY=${config.sops.placeholder."proxy/origin_proof_key"}
        ORIGIN_PROOF_ACCESS_TOKEN=${config.sops.placeholder."proxy/origin_proof_token"}
      '';
    };

    systemd.services.proxy-origin-proof = {
      description = "Loopback proxy origin identity proof";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        EnvironmentFile = config.sops.templates."proxy-origin-proof.env".path;
        Environment = [
          "ORIGIN_PROOF_ID=${cfg.originId}"
          "ORIGIN_PROOF_PORT=${toString cfg.port}"
          "ORIGIN_PROOF_PATH=${cfg.path}"
        ];
        ExecStart = "${pkgs.nodejs}/bin/node ${cfg.package}/origin-proof/server.mjs";
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

    services.nginx.virtualHosts.${cfg.serverName}.locations."=${cfg.path}" = {
      proxyPass = "http://127.0.0.1:${toString cfg.port}";
      extraConfig = ''
        proxy_cache off;
        proxy_buffering off;
        proxy_set_header Cache-Control "no-store";
        add_header Cache-Control "no-store, max-age=0" always;
      '';
    };
  };
}
