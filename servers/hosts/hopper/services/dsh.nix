# ---
# Module: Hopper DSH Service
# Description: Runs DeepSeek Harness behind a restricted local Nginx ingress
# Scope: Host
# Notes:
# - Disabled by default; no users, units, listeners, SOPS references, or backup paths when disabled.
# - The DSH process is not a VM or container security boundary.
# ---

{ config, lib, pkgs, ... }:
let
  cfg = config.dot.hopper.dsh;
  loopback = lib.concatStringsSep "." (map toString [ 127 0 0 1 ]);
  state = "/var/lib/dsh";
  stage = "/var/lib/restic/staging/dsh";
  cloudflare = cfg.ingress == "cloudflare";
  easytier = cfg.ingress == "easytier";
  validHostName = cfg.hostName != null
    && builtins.match "[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+" cfg.hostName != null;
  packageLockReady = cfg.upstreamVersion != null
    && (cfg.package.packageLockPresent or false)
    && (cfg.package.packageManifestVersion or null) == cfg.upstreamVersion
    && (cfg.package.packageLockDeclaredVersion or null) == cfg.upstreamVersion
    && (cfg.package.packageLockVersion or null) == cfg.upstreamVersion
    && (cfg.package.packageLockResolved or null) != null
    && (cfg.package.packageLockIntegrity or null) != null
    && (cfg.package.npmDepsHash or lib.fakeHash) != lib.fakeHash;
  remoteEnabled = cfg.remote.enable || (config.services.dsh.remote.enable or false);
  remotePatchFile = pkgs.writeText "dsh-remote-patch.yml" ''
    - insert:
        - id: ds-harness-remote
          name: ds-harness-remote
          config:
            enabled: true
            role: host
            serverUrl: https://${cfg.remote.relayServer}
            forceRelay: ${if cfg.remote.forceRelay then "true" else "false"}
  '';
  args = [ "--profile" "web" ]
    ++ lib.optionals remoteEnabled [
      "--patch" "${remotePatchFile}"
    ]
    ++ [ "--host" loopback "--port" "3080" "--no-open" ]
    ++ lib.optionals (cfg.hostName != null) [
      "--public-url" "https://${cfg.hostName}/"
      "--trusted-host" cfg.hostName
    ];
in {
  options.dot.hopper.dsh = {
    enable = lib.mkEnableOption "Hopper 上的独立 DeepSeek Harness 服务";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./dsh-package { };
      description = "锁定上游版本与依赖完整性后的 DSH 原生运行包。";
    };
    upstreamVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "0.2.2-rc.1";
      description = "用户确认的精确 npm 发布版本；不得使用 latest。";
    };
    ingress = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "cloudflare" "easytier" ]);
      default = "cloudflare";
      description = "明确选择 Cloudflare Tunnel 或 EasyTier 内网入口。";
    };
    tunnelEnable = lib.mkOption { type = lib.types.bool; default = false; };
    hostName = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    modelBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://llm.bdot.in/v1";
      description = "OpenAI 兼容模型的 Base URL。";
    };
    modelRouterTokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "dsh/llm_router_token";
      description = "SOPS 密钥字段名，用于存储 LLM router token。";
    };
    remote = {
      enable = lib.mkEnableOption "DSH Remote (ds-harness-remote) 远程连接插件支持";
      relayServer = lib.mkOption {
        type = lib.types.str;
        default = if (config.dot.hopper.dshRemoteServer.enable or false) then config.dot.hopper.dshRemoteServer.hostName else "dsh.r2049.cn";
        description = "DSH Remote 中继服务器地址。";
      };
      forceRelay = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "强制直接走中继服务器，跳过 P2P 打洞尝试以实现秒连。";
      };
    };
  };

  options.services.dsh = {
    remote = {
      enable = lib.mkEnableOption "兼容别名：启用 DSH Remote 远程连接插件支持";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        { assertion = cfg.upstreamVersion != null && builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?" cfg.upstreamVersion != null;
          message = "DSH 必须选择精确的 semver 发布版本，不能使用范围、标签或 latest。"; }
        { assertion = packageLockReady;
          message = "DSH 的 package.json、package-lock.json、resolved/integrity 与真实 npmDepsHash 未全部一致；依赖锁定完成前禁止启用。"; }
        { assertion = !easytier;
          message = "DSH EasyTier 入口暂不可启用；共享模块尚未提供可验证的设备接口绑定。"; }
        { assertion = validHostName; message = "DSH 必须在私有 overlay 指定有效域名。"; }
        { assertion = cfg.ingress != null; message = "DSH 必须明确选择入口方式。"; }
        { assertion = config.dot.services.resticBackup.enable; message = "DSH 启用前必须启用 Hopper 本地 Restic 备份。"; }
        { assertion = builtins.match "dsh/[A-Za-z0-9_-]+" cfg.modelRouterTokenSecret != null;
          message = "模型 SOPS 键名必须位于 dsh/ 命名空间。"; }
        { assertion = !cfg.tunnelEnable || cloudflare; message = "仅 Cloudflare 模式可启用 Tunnel。"; }
      ];

      users.groups.dsh = {};
      users.users.dsh = {
        isSystemUser = true;
        group = "dsh";
        home = "${state}/home";
        createHome = false;
        description = "Hopper DeepSeek Harness service";
      };

      sops.secrets.${cfg.modelRouterTokenSecret} = {
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "dsh.service" ];
      };

      systemd.tmpfiles.rules = [
        "d ${state} ${if config.dot.hopper.dsh.codingAgents.enable then "0710 root dsh-workspace" else "0700 dsh dsh"} -"
        "d ${state}/home 0700 dsh dsh -"
        "L+ ${state}/home/node_modules - - - - ${cfg.package}/libexec/dsh/node_modules"
        "d ${state}/home/ds-harness-remote 0700 dsh dsh -"
        "d ${state}/workspaces ${if config.dot.hopper.dsh.codingAgents.enable then "2770 dsh dsh-workspace" else "0700 dsh dsh"} -"
        "d /run/dsh-backup-session 0700 root root -"
      ];

      systemd.services.dsh = let
        dshLauncher = pkgs.writeShellScript "dsh-launcher" ''
          set -euo pipefail

          cred_file="''${CREDENTIALS_DIRECTORY:-}/llm-router-token"
          if [ ! -f "$cred_file" ] || [ ! -s "$cred_file" ]; then
            echo "CRITICAL: LLM router token credential missing or empty; refusing to start unauthenticated" >&2
            exit 1
          fi

          export OPENAI_BASE_URL="${cfg.modelBaseUrl}"
          export OPENAI_API_BASE="${cfg.modelBaseUrl}"
          export OPENAI_API_KEY="$(cat "$cred_file")"
          export DSH_MODEL_API_KEY="$OPENAI_API_KEY"
          export DEEPSEEK_API_KEY="$OPENAI_API_KEY"
          export DEEPSEEK_BASE_URL="${cfg.modelBaseUrl}"

          exec ${lib.getExe cfg.package} ${lib.escapeShellArgs args}
        '';
      in {
        description = "Hopper DeepSeek Harness";
        unitConfig.ConditionPathExists = "!/run/dsh-backup-session/dsh-paused";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" "sops-install-secrets.service" ];
        path = [ pkgs.git pkgs.bash pkgs.coreutils ];
        environment = {
          HOME = "${state}/home";
          DSH_HOME = "${state}/home";
          XDG_CACHE_HOME = "/var/cache/dsh";
        };
        serviceConfig = {
          User = "dsh";
          Group = "dsh";
          WorkingDirectory = "${state}/workspaces";
          LoadCredential = "llm-router-token:${config.sops.secrets.${cfg.modelRouterTokenSecret}.path}";
          ExecStart = "${dshLauncher}";
          Type = "exec";
          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStopSec = "90s";
          LimitFSIZE = "1G";
          SupplementaryGroups = lib.optionals config.dot.hopper.dsh.codingAgents.enable [ "dsh-workspace" ];
          CacheDirectory = "dsh";
          CacheDirectoryMode = "0700";
          LogsDirectory = "dsh";
          LogsDirectoryMode = "0700";
          StandardOutput = "append:/var/log/dsh/runtime.log";
          StandardError = "append:/var/log/dsh/runtime.log";
          UMask = if config.dot.hopper.dsh.codingAgents.enable then "0007" else "0077";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
          ReadWritePaths = [ "${state}/home" "${state}/workspaces" "/var/cache/dsh" "/var/log/dsh" ];
        };
      };

      services.nginx.virtualHosts."dsh-local" = {
        serverName = if cfg.hostName == null then "dsh.invalid" else cfg.hostName;
        listen = [{ addr = loopback; port = 3081; }];
        extraConfig = ''
          access_log off;
          error_log /var/log/nginx/dsh-error.log crit;
          client_max_body_size 25m;
        '';
        locations."/" = {
          proxyPass = "http://${loopback}:3080";
          proxyWebsockets = true;
          # 继承 Hopper recommendedProxySettings 的 Host 头，不重复声明。
          extraConfig = ''
            proxy_buffering off;
            proxy_read_timeout 3600s;
            proxy_cookie_flags ~ secure;
          '';
        };
      };

      # 只追加 staging 路径；共享 Restic 模块的字符串型 prepare/cleanup hook 不修改。
      services.restic.backups.hopper-local = {
        paths = lib.mkAfter [ stage ];
        exclude = lib.mkAfter [ "${state}/workspaces/.agent-jobs" "${state}/workspaces/.agent-auth" ];
      };

      # Requires + After 确保每次 Restic 启动都先完成停写与归档；
      # OnSuccess/OnFailure 则覆盖备份成功和失败两条恢复路径。
      systemd.services.dsh-backup-prepare = {
        description = "Quiesce Hopper DSH writers before local Restic backup";
        requires = [ "mongodb-backup-privileges.service" ];
        after = [ "mongodb-backup-privileges.service" ];
        path = [ pkgs.systemd pkgs.gnutar ];
        unitConfig.OnFailure = "dsh-backup-resume.service";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          UMask = "0077";
          TimeoutStartSec = "5min";
          ExecStart = "${pkgs.python3}/bin/python3 ${./dsh-backup-session.py} prepare";
        };
      };

      systemd.services.dsh-backup-resume = {
        description = "Restore Hopper DSH writers after local Restic backup";
        unitConfig.OnFailure = "dsh-backup-recovery-alert.service";
        path = [ pkgs.systemd pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          UMask = "0077";
          TimeoutStartSec = "5min";
          ExecStart = "${pkgs.python3}/bin/python3 ${./dsh-backup-session.py} resume";
        };
      };

      systemd.services.dsh-backup-recovery-alert = {
        description = "Emit a secret-free critical alert when DSH backup recovery is incomplete";
        path = [ pkgs.systemd pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStart = "${pkgs.systemd}/bin/systemd-cat --priority=crit --identifier=dsh-backup-session ${pkgs.coreutils}/bin/echo DSH-backup-recovery-incomplete-check-state-file";
        };
      };

      systemd.services.restic-backups-hopper-local = {
        requires = [ "dsh-backup-prepare.service" ];
        after = [ "dsh-backup-prepare.service" ];
        unitConfig = {
          OnSuccess = "dsh-backup-resume.service";
          OnFailure = "dsh-backup-resume.service";
        };
      };

    }

    (lib.mkIf (cloudflare && cfg.tunnelEnable) {
      sops.secrets."dsh/cloudflare_tunnel_token" = {
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "dsh-tunnel.service" ];
      };
      systemd.services.dsh-tunnel = {
        description = "DSH 专用 Cloudflare Tunnel 连接器";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" "nginx.service" "sops-install-secrets.service" ];
        serviceConfig = {
          DynamicUser = true;
          LoadCredential = "tunnel-token:${config.sops.secrets."dsh/cloudflare_tunnel_token".path}";
          ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/tunnel-token";
          Restart = "on-failure";
          RestartSec = "10s";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        };
      };
    })

  ]);
}
