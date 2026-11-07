# ---
# Module: Hopper DSH Remote Server Service
# Description: Self-hosted DSH Remote Server relay service and Nginx reverse proxy
# Scope: Host
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.hopper.dshRemoteServer;
  originAlias = "${lib.removeSuffix ".bdot.in" cfg.hostName}-origin.bdot.in";
in
{
  options.dot.hopper.dshRemoteServer = {
    enable = lib.mkEnableOption "Hopper 上的自建 DSH Remote Server 中继服务";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      description = "DSH Remote Server 原生 Node.js 运行包。";
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      default = "dsh-relay.bdot.in";
      description = "DSH Remote Server 公网访问域名。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3085;
      description = "本地监听端口。";
    };

    account = lib.mkOption {
      type = lib.types.str;
      default = "dot@bdot.in";
      description = "DSH Remote Server 登录账号。";
    };

    passwordSecret = lib.mkOption {
      type = lib.types.str;
      default = "dsh/remote_server_password";
      description = "SOPS 密钥字段名，用于存储 DSH Remote Server 登录密码。";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/dsh-remote-server";
      description = "状态与设备凭据数据持久化目录。";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.dsh-remote = { };
    users.users.dsh-remote = {
      isSystemUser = true;
      group = "dsh-remote";
      home = cfg.stateDir;
      createHome = false;
      description = "DSH Remote Server daemon user";
    };

    sops.secrets.${cfg.passwordSecret} = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "dsh-remote-server.service" ];
    };


    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0700 dsh-remote dsh-remote -"
    ];

    systemd.services.dsh-remote-server = {
      description = "DeepSeek Harness Remote Relay Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "dsh-remote";
        Group = "dsh-remote";
        WorkingDirectory = cfg.stateDir;
        LoadCredential = [
          "server-password:${config.sops.secrets.${cfg.passwordSecret}.path}"
        ];
        ExecStart = let
          launcher = pkgs.writeShellScript "dsh-remote-server-launcher" ''
            set -euo pipefail

            cred="''${CREDENTIALS_DIRECTORY:-}/server-password"
            if [ ! -f "$cred" ] || [ ! -s "$cred" ]; then
              echo "dsh-remote-server: missing required password credential" >&2
              exit 1
            fi

            export DSH_SERVER_ACCOUNT="${cfg.account}"
            export DSH_SERVER_PASSWORD="$(< "$cred")"
            export DSH_SERVER_PUBLIC_URL="https://${cfg.hostName}"
            export DSH_SERVER_HOST="127.0.0.1"
            export DSH_SERVER_PORT="${toString cfg.port}"
            export DSH_SERVER_DATA_FILE="${cfg.stateDir}/state.json"
            export DSH_SERVER_TRUSTED_PROXY_IPS="127.0.0.1"

            exec ${cfg.package}/bin/dsh-remote-server
          '';
        in "${launcher}";
        Restart = "always";
        RestartSec = "5s";

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.stateDir ];
        PrivateTmp = true;
      };
    };

    services.nginx.virtualHosts."${cfg.hostName}" = {
      serverAliases = lib.optional (originAlias != cfg.hostName) originAlias;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    };
  };
}
