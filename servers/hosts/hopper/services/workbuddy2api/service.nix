# ---
# Module: Hopper WorkBuddy2API Service
# Description: WorkBuddy / CodeBuddy OpenAI-compatible API gateway and management panel
# Scope: Host
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.hopper.workbuddy2api;
  originAlias = if cfg.hostName != null
    then "${lib.removeSuffix ".bdot.in" cfg.hostName}-origin.bdot.in"
    else null;
in
{
  options.dot.hopper.workbuddy2api = {
    enable = lib.mkEnableOption "Hopper 上的 WorkBuddy2API 转发网关与管理面板服务";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      description = "WorkBuddy2API 原生二进制包。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7863;
      description = "本地监听端口。";
    };

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "wb.bdot.in";
      description = "Web 管理面板公网访问域名（SaaS 回源）。若为 null 则仅监听本地回环。";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/workbuddy2api";
      description = "配置与账号数据持久化目录。";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.workbuddy2api = { };
    users.users.workbuddy2api = {
      isSystemUser = true;
      group = "workbuddy2api";
      home = cfg.stateDir;
      createHome = false;
      description = "WorkBuddy2API daemon user";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0700 workbuddy2api workbuddy2api -"
      "d ${cfg.stateDir}/data 0700 workbuddy2api workbuddy2api -"
      "d ${cfg.stateDir}/auths 0700 workbuddy2api workbuddy2api -"
    ];

    systemd.services.workbuddy2api = {
      description = "WorkBuddy / CodeBuddy OpenAI-compatible Gateway and Web Panel";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "workbuddy2api";
        Group = "workbuddy2api";
        WorkingDirectory = cfg.stateDir;
        ExecStart = let
          launcher = pkgs.writeShellScript "workbuddy2api-launcher" ''
            set -euo pipefail

            if [ ! -f "${cfg.stateDir}/config.json" ]; then
              random_key="wb_$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
              cat <<EOF > "${cfg.stateDir}/config.json"
{
  "listen": "127.0.0.1:${toString cfg.port}",
  "api_key": "$random_key",
  "auth_dir": "${cfg.stateDir}/auths",
  "state_file": "${cfg.stateDir}/data/state.json",
  "global": {
    "enabled": true
  },
  "cn": {
    "enabled": false
  }
}
EOF
              chmod 600 "${cfg.stateDir}/config.json"
            fi

            exec ${cfg.package}/bin/wb2api
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

    services.nginx.virtualHosts = lib.mkIf (cfg.hostName != null) {
      "${cfg.hostName}" = {
        serverAliases = [ "dsh-wb.bdot.in" ] ++ lib.optional (originAlias != null && originAlias != cfg.hostName) originAlias;
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
  };
}
