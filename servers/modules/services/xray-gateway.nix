# ---
# Module: Server Xray Gateway
# Description: Native VLESS REALITY gateway with protected CDN egress routing
# Scope: System
# Notes:
# - Authentication and relay values come from sops-nix and never enter the Nix store.
# - CDN prefixes follow fatekey/gcp_free commit f09a731 and require periodic review.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.xrayGateway;

  cdnIPv4Ranges = [
    # Akamai
    "23.32.0.0/11"
    "23.192.0.0/11"
    "2.16.0.0/13"
    "104.64.0.0/10"
    "184.24.0.0/13"
    "23.0.0.0/12"
    "95.100.0.0/15"
    "92.122.0.0/15"
    "184.50.0.0/15"
    "88.221.0.0/16"
    "23.64.0.0/14"
    "72.246.0.0/15"
    "96.16.0.0/15"
    "96.6.0.0/15"
    "69.192.0.0/16"
    "23.72.0.0/13"
    "173.222.0.0/15"
    "118.214.0.0/16"
    "184.84.0.0/14"

    # Cloudflare
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"

    # Fastly
    "23.235.32.0/20"
    "43.249.72.0/22"
    "103.244.50.0/24"
    "103.245.222.0/23"
    "103.245.224.0/24"
    "104.156.80.0/20"
    "140.248.64.0/18"
    "140.248.128.0/17"
    "146.75.0.0/17"
    "151.101.0.0/16"
    "157.52.64.0/18"
    "167.82.0.0/17"
    "167.82.128.0/20"
    "167.82.160.0/20"
    "167.82.224.0/20"
    "172.111.64.0/18"
    "185.31.16.0/22"
    "199.27.72.0/21"
    "199.232.0.0/16"
  ];

  secret = name: config.sops.placeholder."xray/${name}";

  settings = {
    log.loglevel = "warning";

    inbounds = [
      {
        tag = "public-vless-reality";
        listen = "0.0.0.0";
        port = cfg.listenPort;
        protocol = "vless";
        settings = {
          clients = [
            {
              id = secret "inbound_uuid";
              flow = "xtls-rprx-vision";
              email = "dot";
            }
          ];
          decryption = "none";
        };
        streamSettings = {
          network = "raw";
          security = "reality";
          realitySettings = {
            show = false;
            target = cfg.realityTarget;
            xver = 0;
            serverNames = [ cfg.realityServerName ];
            privateKey = secret "reality_private_key";
            shortIds = [ (secret "reality_short_id") ];
            limitFallbackUpload = {
              afterBytes = 1048576;
              bytesPerSec = 65536;
              burstBytesPerSec = 262144;
            };
            limitFallbackDownload = {
              afterBytes = 1048576;
              bytesPerSec = 65536;
              burstBytesPerSec = 262144;
            };
          };
        };
        sniffing = {
          enabled = true;
          destOverride = [
            "http"
            "tls"
            "quic"
          ];
          routeOnly = true;
        };
      }
    ];

    outbounds = [
      {
        tag = "direct";
        protocol = "freedom";
        settings.domainStrategy = "UseIP";
      }
      {
        tag = "cdn-relay";
        protocol = "vless";
        settings.vnext = [
          {
            address = secret "relay_address";
            port = cfg.relayPort;
            users = [
              {
                id = secret "relay_uuid";
                encryption = "none";
              }
            ];
          }
        ];
        streamSettings = {
          network = "ws";
          security = "none";
          wsSettings = {
            path = secret "relay_ws_path";
            headers.Host = secret "relay_ws_host";
          };
        };
      }
      {
        tag = "blocked";
        protocol = "blackhole";
        settings.response.type = "http";
      }
    ];

    routing = {
      domainStrategy = "IPIfNonMatch";
      rules = [
        {
          type = "field";
          ip = [ "geoip:private" ];
          outboundTag = "blocked";
        }
        {
          type = "field";
          protocol = [ "bittorrent" ];
          outboundTag = "blocked";
        }
        {
          type = "field";
          ip = cdnIPv4Ranges;
          outboundTag = "cdn-relay";
        }
      ];
    };
  };

  xraySecretNames = [
    "inbound_uuid"
    "reality_private_key"
    "reality_short_id"
    "relay_address"
    "relay_uuid"
    "relay_ws_host"
    "relay_ws_path"
  ];
in
{
  options.dot.services.xrayGateway = {
    enable = lib.mkEnableOption "the public Xray VLESS REALITY gateway";

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "Public TCP port used by the REALITY inbound.";
    };

    relayPort = lib.mkOption {
      type = lib.types.port;
      default = 80;
      description = "TCP port used by the protected CDN relay.";
    };

    realityTarget = lib.mkOption {
      type = lib.types.str;
      default = "www.google.com:443";
      description = "TLS target used for REALITY camouflage.";
    };

    realityServerName = lib.mkOption {
      type = lib.types.str;
      default = "www.google.com";
      description = "Allowed REALITY client SNI.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs (map (name: "xray/${name}") xraySecretNames) (_: {
      restartUnits = [ "xray.service" ];
    });

    sops.templates."xray-gateway.json" = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = builtins.toJSON settings;
    };

    services.xray = {
      enable = true;
      settingsFile = config.sops.templates."xray-gateway.json".path;
    };

    networking.firewall.allowedTCPPorts = [ cfg.listenPort ];

    systemd.services.xray = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
}
