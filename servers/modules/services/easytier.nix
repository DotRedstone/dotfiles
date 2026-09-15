# ---
# Module: Server EasyTier
# Description: Rootless EasyTier mesh client with runtime-decrypted network credentials
# Scope: System
# Notes:
# - The generated environment file contains secrets and must never be placed in the Nix store.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.easytier;
in
{
  options.dot.services.easytier = {
    enable = lib.mkEnableOption "the EasyTier mesh client";

    ipv4 = lib.mkOption {
      type = lib.types.str;
      description = "Static EasyTier IPv4 address without a prefix length.";
      example = "10.8.0.4";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Hostname announced to EasyTier peers.";
    };

    useNetworkSecret = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether this EasyTier network authenticates with a non-empty network secret.";
    };

    peers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Bootstrap peer URIs.";
      example = [ "tcp://203.0.113.10:11010" ];
    };

    noListener = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Only initiate peer connections instead of exposing public listeners.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 11010;
      description = "TCP and UDP port exposed when listener mode is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.peers != [ ];
        message = "dot.services.easytier.peers must contain at least one bootstrap peer.";
      }
    ];

    sops.secrets = {
      "easytier/network_name" = {
        restartUnits = [ "easytier.service" ];
      };
    } // lib.optionalAttrs cfg.useNetworkSecret {
      "easytier/network_secret" = {
        restartUnits = [ "easytier.service" ];
      };
    };

    sops.templates."easytier.env" = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        ET_NETWORK_NAME=${config.sops.placeholder."easytier/network_name"}
        ${lib.optionalString cfg.useNetworkSecret "ET_NETWORK_SECRET=${config.sops.placeholder."easytier/network_secret"}"}
        ET_IPV4=${cfg.ipv4}
        ET_HOSTNAME=${cfg.hostname}
        ET_INSTANCE_NAME=${cfg.hostname}
        # clap parses list-valued environment variables with comma delimiters.
        ET_PEERS=${lib.concatStringsSep "," cfg.peers}
        ET_NO_LISTENER=${lib.boolToString cfg.noListener}
        ${lib.optionalString (!cfg.noListener) "ET_LISTENERS=${toString cfg.listenPort}"}
        ET_DISABLE_IPV6=true
        ET_DISABLE_UPNP=true
        ET_LATENCY_FIRST=true
        ET_CONSOLE_LOG_LEVEL=warn
      '';
    };

    users = {
      groups.easytier = { };
      users.easytier = {
        isSystemUser = true;
        group = "easytier";
        home = "/var/lib/easytier";
      };
    };

    environment.systemPackages = [ pkgs.easytier ];

    networking.firewall = {
      allowedTCPPorts = lib.optionals (!cfg.noListener) [ cfg.listenPort ];
      allowedUDPPorts = lib.optionals (!cfg.noListener) [ cfg.listenPort ];
    };

    systemd.services.easytier = {
      description = "EasyTier mesh client";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "easytier";
        Group = "easytier";
        ExecStart = "${pkgs.easytier}/bin/easytier-core";
        EnvironmentFile = config.sops.templates."easytier.env".path;
        Restart = "always";
        RestartSec = "5s";

        StateDirectory = "easytier";
        WorkingDirectory = "/var/lib/easytier";
        UMask = "0077";
        LimitNOFILE = 65535;

        AmbientCapabilities = [
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
        ];
        DeviceAllow = [ "/dev/net/tun rw" ];
        DevicePolicy = "closed";
        NoNewPrivileges = true;
        PrivateDevices = false;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_UNIX"
        ];
      };
    };
  };
}
