# ---
# Module: Server Xray Node
# Description: Native VLESS WebSocket and REALITY endpoints with runtime-decrypted credentials
# Scope: System
# Notes:
# - Client UUIDs and cryptographic material never enter the Nix store.
# - The current high ports receive no ambient capabilities; grant CAP_NET_BIND_SERVICE before using 443.
# ---

{
  config,
  lib,
  ...
}:

let
  cfg = config.dot.services.xrayNode;
  secret = name: config.sops.placeholder."xray/${name}";
  realityShortIdNames = builtins.genList (index: "reality_short_id_${toString index}") 8;
  webSocketClientSecretNames =
    if cfg.webSocketClientCount == 1 then
      [ "websocket_client_uuid" ]
    else
      builtins.genList (index: "websocket_client_uuid_${toString index}") cfg.webSocketClientCount;

  settings = {
    log.loglevel = "warning";

    inbounds = [
      {
        tag = "vless-websocket";
        listen = "0.0.0.0";
        port = cfg.webSocketPort;
        protocol = "vless";
        settings = {
          clients = lib.imap0 (index: name: {
            id = secret name;
            email =
              if cfg.webSocketClientCount == 1 then
                "${config.networking.hostName}-websocket"
              else
                "${config.networking.hostName}-websocket-${toString index}";
          }) webSocketClientSecretNames;
          decryption = "none";
          encryption = "none";
        };
        streamSettings = {
          network = "ws";
          security = "none";
          wsSettings = {
            path = secret "websocket_path";
            headers = { };
          };
        };
      }

      {
        tag = "vless-reality";
        listen = cfg.realityListenAddress;
        port = cfg.realityPort;
        protocol = "vless";
        settings = {
          clients = [
            {
              id = secret "reality_client_uuid";
              email = "${config.networking.hostName}-reality";
            }
          ];
          decryption = "none";
          encryption = "none";
        };
        streamSettings = {
          network = "tcp";
          security = "reality";
          realitySettings = {
            show = false;
            xver = 0;
            target = cfg.realityTarget;
            serverNames = [ cfg.realityServerName ];
            privateKey = secret "reality_private_key";
            shortIds = map secret realityShortIdNames;
            mldsa65Seed = secret "reality_mldsa65_seed";
          };
          tcpSettings.header.type = "none";
        };
      }
    ];

    outbounds = [
      {
        tag = "direct";
        protocol = "freedom";
        settings.domainStrategy = "AsIs";
      }
      {
        tag = "blocked";
        protocol = "blackhole";
        settings = { };
      }
    ];

    routing = {
      domainStrategy = "AsIs";
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
      ];
    };
  };

  secretNames = [
    "websocket_path"
    "reality_client_uuid"
    "reality_private_key"
    "reality_mldsa65_seed"
  ]
  ++ webSocketClientSecretNames
  ++ realityShortIdNames;
in
{
  options.dot.services.xrayNode = {
    enable = lib.mkEnableOption "the native Xray edge node";

    webSocketPort = lib.mkOption {
      type = lib.types.port;
      default = 20001;
      description = "Public VLESS WebSocket port.";
    };

    webSocketClientCount = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Number of independently authenticated VLESS WebSocket clients.";
    };

    realityPort = lib.mkOption {
      type = lib.types.port;
      default = 20002;
      description = "Public VLESS REALITY port.";
    };

    realityListenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "IPv4 address used by the REALITY listener.";
    };

    realityTarget = lib.mkOption {
      type = lib.types.str;
      description = "TLS target used for REALITY camouflage.";
      example = "www.example.com:443";
    };

    realityServerName = lib.mkOption {
      type = lib.types.str;
      description = "Allowed REALITY client SNI.";
      example = "www.example.com";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs (map (name: "xray/${name}") secretNames) (_: {
      restartUnits = [ "xray.service" ];
    });

    sops.templates."xray-node.json" = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = builtins.toJSON settings;
    };

    services.xray = {
      enable = true;
      settingsFile = config.sops.templates."xray-node.json".path;
    };

    networking.firewall.allowedTCPPorts = [
      cfg.webSocketPort
      cfg.realityPort
    ];

    systemd.services.xray = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
        AmbientCapabilities = lib.mkForce [ ];
        CapabilityBoundingSet = lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
        LockPersonality = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };
  };
}
