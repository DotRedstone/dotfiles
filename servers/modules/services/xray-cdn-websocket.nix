# ---
# Module: Xray CDN WebSocket
# Description: Terminate Cloudflare-origin TLS and proxy WebSocket traffic to the local VLESS inbound.
# Scope: System
# Notes:
# - The DNS record must be Cloudflare-proxied with Full (strict) SSL mode.
# - This does not replace the direct WebSocket or REALITY listeners.
# ---

{
  config,
  lib,
  ...
}:

let
  cfg = config.dot.services.xrayCdnWebSocket;
in
{
  options.dot.services.xrayCdnWebSocket = {
    enable = lib.mkEnableOption "the Cloudflare-fronted VLESS WebSocket endpoint";

    serverName = lib.mkOption {
      type = lib.types.str;
      example = "la-cdn.example.com";
      description = "Cloudflare-proxied hostname used by VLESS WebSocket clients.";
    };

    webSocketPort = lib.mkOption {
      type = lib.types.port;
      default = 20001;
      description = "Loopback-reachable Xray VLESS WebSocket inbound port.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "xray/cdn_origin_certificate" = {
        owner = "root";
        group = "nginx";
        mode = "0440";
        restartUnits = [ "nginx.service" ];
      };
      "xray/cdn_origin_certificate_key" = {
        owner = "root";
        group = "nginx";
        mode = "0440";
        restartUnits = [ "nginx.service" ];
      };
    };

    services.nginx.virtualHosts.${cfg.serverName} = {
      addSSL = true;
      sslCertificate = config.sops.secrets."xray/cdn_origin_certificate".path;
      sslCertificateKey = config.sops.secrets."xray/cdn_origin_certificate_key".path;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.webSocketPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [ 443 ];
  };
}
