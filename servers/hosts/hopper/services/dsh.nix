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
  marker = "/run/restic-backups-hopper-local-dsh-was-active";
  cloudflare = cfg.ingress == "cloudflare";
  easytier = cfg.ingress == "easytier";
  hasModelKey = cfg.modelApiKeyEnv != null && cfg.modelApiKeySecret != null;
  validHostName = cfg.hostName != null
    && builtins.match "[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+" cfg.hostName != null;
  args = [ "web" "--host" loopback "--port" "3080" "--no-open" ]
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
      default = null;
      description = "用户确认的精确 npm 发布版本；不得使用 latest。";
    };
    ingress = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "cloudflare" "easytier" ]);
      default = null;
      description = "明确选择 Cloudflare Tunnel 或 EasyTier 内网入口。";
    };
    tunnelEnable = lib.mkOption { type = lib.types.bool; default = false; };
    hostName = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    modelApiKeyEnv = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    modelApiKeySecret = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    meshInterface = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    meshListenAddress = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    meshCertificate = lib.mkOption { type = lib.types.nullOr lib.types.path; default = null; };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        { assertion = cfg.upstreamVersion != null && cfg.upstreamVersion != "" && lib.toLower cfg.upstreamVersion != "latest";
          message = "DSH 必须选择精确上游版本并与 npm 锁文件一致。"; }
        { assertion = validHostName; message = "DSH 必须在私有 overlay 指定有效域名。"; }
        { assertion = cfg.ingress != null; message = "DSH 必须明确选择入口方式。"; }
        { assertion = config.dot.services.resticBackup.enable; message = "DSH 启用前必须启用 Hopper 本地 Restic 备份。"; }
        { assertion = (cfg.modelApiKeyEnv == null) == (cfg.modelApiKeySecret == null);
          message = "模型 key 环境变量与 SOPS 键名必须同时设置或同时留空。"; }
        { assertion = cfg.modelApiKeyEnv == null || builtins.match "[A-Za-z_][A-Za-z0-9_]*" cfg.modelApiKeyEnv != null;
          message = "modelApiKeyEnv 必须是有效环境变量名。"; }
        { assertion = cfg.modelApiKeySecret == null || builtins.match "dsh/[A-Za-z0-9_-]+" cfg.modelApiKeySecret != null;
          message = "模型 SOPS 键名必须位于 dsh/ 命名空间。"; }
        { assertion = !cfg.tunnelEnable || cloudflare; message = "仅 Cloudflare 模式可启用 Tunnel。"; }
      ];

      users.groups.dsh = {};
      users.users.dsh = {
        isSystemUser = true;
        group = "dsh";
        home = state;
        createHome = false;
        description = "Hopper DeepSeek Harness service";
      };

      sops.secrets = lib.optionalAttrs hasModelKey {
        ${cfg.modelApiKeySecret} = {
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [ "dsh.service" ];
        };
      };
      sops.templates = lib.optionalAttrs hasModelKey {
        "dsh.env" = {
          owner = "root";
          group = "root";
          mode = "0400";
          content = ''
            ${cfg.modelApiKeyEnv}=${config.sops.placeholder.${cfg.modelApiKeySecret}}
          '';
          restartUnits = [ "dsh.service" ];
        };
      };

      systemd.tmpfiles.rules = [
        "d ${state}/home 0700 dsh dsh -"
        "d ${state}/workspaces 0700 dsh dsh -"
        "f /var/log/dsh/nginx-error.log 0600 root root -"
      ] ++ lib.optionals config.dot.hopper.dsh.codingAgents.enable [
        "d ${state} 0710 dsh dsh-workspace -"
        "d ${state}/workspaces 2770 dsh dsh-workspace -"
      ];

      systemd.services.dsh = {
        description = "Hopper DeepSeek Harness";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" "sops-install-secrets.service" ];
        path = [ pkgs.git pkgs.bash pkgs.coreutils ];
        environment = {
          HOME = state;
          DSH_HOME = "${state}/home";
          XDG_CACHE_HOME = "/var/cache/dsh";
        };
        serviceConfig = {
          User = "dsh";
          Group = "dsh";
          WorkingDirectory = "${state}/workspaces";
          EnvironmentFile = if hasModelKey then config.sops.templates."dsh.env".path else "/dev/null";
          ExecStart = "${lib.getExe cfg.package} ${lib.escapeShellArgs args}";
          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStopSec = "90s";
          StateDirectory = "dsh";
          StateDirectoryMode = if config.dot.hopper.dsh.codingAgents.enable then "0710" else "0700";
          SupplementaryGroups = lib.optionals config.dot.hopper.dsh.codingAgents.enable [ "dsh-workspace" ];
          CacheDirectory = "dsh";
          CacheDirectoryMode = "0700";
          LogsDirectory = "dsh";
          LogsDirectoryMode = "0700";
          StandardOutput = "append:/var/log/dsh/runtime.log";
          StandardError = "append:/var/log/dsh/runtime.log";
          UMask = "0077";
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
          error_log /var/log/dsh/nginx-error.log crit;
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

      # 独立 staging 路径，追加到现有备份，不覆盖数据库导出。
      services.restic.backups.hopper-local = {
        paths = lib.mkAfter [ stage ];
        exclude = lib.mkAfter [ "${state}/workspaces/.agent-jobs" "${state}/workspaces/.agent-auth" ];
        backupPrepareCommand = lib.mkAfter ''
          set -euo pipefail
          umask 077
          install -d -m 0700 ${stage}
          rm -f ${marker}
          if ${pkgs.systemd}/bin/systemctl is-active --quiet dsh.service; then
            install -m 0600 /dev/null ${marker}
          fi
          resume_dsh() {
            if [ -e ${marker} ]; then
              ${pkgs.systemd}/bin/systemctl start dsh.service
              ${pkgs.coreutils}/bin/rm -f ${marker}
            fi
          }
          trap resume_dsh EXIT
          if [ -e ${marker} ]; then
            ${pkgs.systemd}/bin/systemctl stop dsh.service
          fi
          ${pkgs.gnutar}/bin/tar --no-xattrs \
            --exclude=dsh/workspaces/.agent-jobs \
            --exclude=dsh/workspaces/.agent-auth \
            -C /var/lib -cpf ${stage}/dsh.tar dsh
          resume_dsh
          trap - EXIT
        '';
        backupCleanupCommand = lib.mkAfter ''
          ${pkgs.coreutils}/bin/rm -f ${stage}/dsh.tar
        '';
      };

      systemd.services.restic-backups-hopper-local.serviceConfig.ExecStopPost =
        lib.mkAfter [
          (pkgs.writeShellScript "restic-hopper-dsh-resume" ''
            set -euo pipefail
            if [ -e ${marker} ]; then
              ${pkgs.systemd}/bin/systemctl start dsh.service
              ${pkgs.coreutils}/bin/rm -f ${marker}
            fi
          '')
        ];
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

    (lib.mkIf easytier {
      assertions = [{
        assertion = config.dot.services.easytier.enable
          && cfg.meshInterface != null && cfg.meshInterface != ""
          && cfg.meshListenAddress != null && cfg.meshListenAddress != ""
          && cfg.meshListenAddress != loopback
          && cfg.meshListenAddress != "0.0.0.0"
          && cfg.meshListenAddress != "::"
          && cfg.meshCertificate != null;
        message = "EasyTier 模式需要 EasyTier、接口专属地址和受信任 TLS 证书，禁止通配监听。";
      }];
      sops.secrets."dsh/mesh_tls_key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      services.nginx.virtualHosts."dsh-local" = {
        listen = lib.mkForce [{
          addr = if cfg.meshListenAddress == null then loopback else cfg.meshListenAddress;
          port = 3081;
          ssl = true;
        }];
        sslCertificateKey = config.sops.secrets."dsh/mesh_tls_key".path;
        sslCertificate = cfg.meshCertificate;
      };
      networking.firewall.interfaces = lib.optionalAttrs (cfg.meshInterface != null) {
        ${cfg.meshInterface}.allowedTCPPorts = [ 3081 ];
      };
    })
  ]);
}
