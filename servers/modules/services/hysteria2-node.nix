# ---
# Module: Hysteria 2 Node
# Description: Run an independently authenticated QUIC proxy endpoint with ACME-backed TLS
# Scope: System
# Notes:
# - This endpoint is intentionally independent from Xray so a lossy TCP path cannot affect it.
# - The HTTP ACME challenge must be proxied by the host's Nginx virtual host.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.hysteria2Node;
  secret = name: config.sops.placeholder."hysteria2/${name}";
  settings = {
    listen = "0.0.0.0:${toString cfg.port}";
    acme = {
      domains = [ cfg.domain ];
      email = cfg.acmeEmail;
      type = "http";
      listenHost = "127.0.0.1";
      http.altPort = cfg.acmeChallengePort;
    };
    auth = {
      type = "password";
      password = secret "auth_password";
    };
    obfs = {
      type = "salamander";
      salamander.password = secret "obfs_password";
    };
    masquerade = {
      type = "proxy";
      proxy = {
        url = cfg.masqueradeUrl;
        rewriteHost = true;
      };
    };
  };
in
{
  options.dot.services.hysteria2Node = {
    enable = lib.mkEnableOption "the native Hysteria 2 QUIC edge node";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "DNS-only hostname used for ACME and client TLS verification.";
      example = "hy2.example.com";
    };

    acmeEmail = lib.mkOption {
      type = lib.types.str;
      description = "Contact email supplied to the ACME certificate authority.";
      example = "admin@example.com";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "Public UDP port used by the Hysteria 2 listener.";
    };

    acmeChallengePort = lib.mkOption {
      type = lib.types.port;
      default = 8888;
      description = "Loopback HTTP port reached by Nginx for ACME HTTP-01 challenges.";
    };

    masqueradeUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://www.cloudflare.com/";
      description = "HTTPS origin used for unauthenticated HTTP/3 masquerading.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.hysteria2 = { };
    users.users.hysteria2 = {
      isSystemUser = true;
      group = "hysteria2";
    };

    sops.secrets = lib.genAttrs [
      "hysteria2/auth_password"
      "hysteria2/obfs_password"
    ] (_: {
      owner = "hysteria2";
      group = "hysteria2";
      restartUnits = [ "hysteria2.service" ];
    });

    sops.templates."hysteria2.yaml" = {
      owner = "hysteria2";
      group = "hysteria2";
      mode = "0400";
      content = builtins.toJSON settings;
    };

    systemd.services.hysteria2 = {
      description = "Hysteria 2 QUIC proxy node";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "hysteria2";
        Group = "hysteria2";
        StateDirectory = "hysteria2";
        WorkingDirectory = "/var/lib/hysteria2";
        ExecStart = "${pkgs.hysteria}/bin/hysteria server --config ${config.sops.templates."hysteria2.yaml".path}";
        Restart = "always";
        RestartSec = "3s";
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

    networking.firewall.allowedUDPPorts = [ cfg.port ];
  };
}
