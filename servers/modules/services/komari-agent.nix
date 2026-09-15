# ---
# Module: Server Komari Agent
# Description: Sandboxed native Komari monitoring agent with encrypted credentials
# Scope: System
# Notes:
# - Remote shell and self-update are disabled; upgrades come from the pinned Nix package.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.komariAgent;
in
{
  options.dot.services.komariAgent.enable = lib.mkEnableOption "the native Komari monitoring agent";

  config = lib.mkIf cfg.enable {
    sops.secrets."komari/endpoint" = {
      restartUnits = [ "komari-agent.service" ];
    };
    sops.secrets."komari/token" = {
      restartUnits = [ "komari-agent.service" ];
    };

    sops.templates."komari-agent.env" = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        AGENT_ENDPOINT=${config.sops.placeholder."komari/endpoint"}
        AGENT_TOKEN=${config.sops.placeholder."komari/token"}
      '';
    };

    systemd.services.komari-agent = {
      description = "Komari monitoring agent";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        AGENT_DISABLE_AUTO_UPDATE = "true";
        AGENT_DISABLE_WEB_SSH = "true";
      };

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        ExecStart = "${lib.getExe pkgs.komari-agent}";
        EnvironmentFile = config.sops.templates."komari-agent.env".path;
        Restart = "always";
        RestartSec = "10s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
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
