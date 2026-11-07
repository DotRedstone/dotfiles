# ---
# Module: Hopper DSH Coding Agents
# Description: Runs fixed local coding-agent jobs under a separate restricted system identity
# Scope: Host
# Notes:
# - Disabled by default; the DSH plugin adapter remains blocked until its exact upstream API is pinned.
# - Codex is the only planned executable; the DSH adapter readiness assertion blocks activation.
# - This is same-host least-privilege isolation, not a VM or a guarantee against data exfiltration.
# ---

{ config, lib, pkgs, ... }:
let
  cfg = config.dot.hopper.dsh.codingAgents;
  dshCfg = config.dot.hopper.dsh;
  agentHome = "/var/lib/dsh-agent";
  workspace = "/var/lib/dsh/workspaces/coding";
  jobs = "/var/lib/dsh/workspaces/.agent-jobs";
  commands = pkgs.writeText "dsh-agent-commands.json" (builtins.toJSON {
    codex = "${cfg.codex.package}/bin/codex";
  });

  commonServiceConfig = {
    Type = "oneshot";
    User = "dsh-agent";
    Group = "dsh-agent";
    SupplementaryGroups = [ "dsh-workspace" ];
    Slice = "dsh-coding.slice";
    WorkingDirectory = workspace;
    UMask = "0007";
    Environment = [
      "HOME=${agentHome}"
      "CODEX_HOME=${agentHome}/codex"
      "XDG_CONFIG_HOME=${agentHome}/config"
      "XDG_DATA_HOME=${agentHome}/data"
      "XDG_CACHE_HOME=${agentHome}/cache"
      "PATH=${lib.makeBinPath [
        cfg.codex.package
        pkgs.bash
        pkgs.coreutils
        pkgs.findutils
        pkgs.git
        pkgs.gnugrep
        pkgs.gnused
        pkgs.gawk
        pkgs.ripgrep
        pkgs.bubblewrap
      ]}"
      "LANG=C.UTF-8"
      "LC_ALL=C.UTF-8"
      "TERM=dumb"
      "NO_COLOR=1"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "GIT_CONFIG_NOSYSTEM=1"
      "GIT_CONFIG_GLOBAL=/dev/null"
      "GIT_TERMINAL_PROMPT=0"
      "GIT_CONFIG_COUNT=1"
      "GIT_CONFIG_KEY_0=credential.helper"
      "GIT_CONFIG_VALUE_0="
    ];
    UnsetEnvironment = [
      "DSH_MODEL_API_KEY"
      "DSH_DEEPSEEK_API_KEY"
      "DSH_OPENAI_API_KEY"
      "DSH_ANTHROPIC_API_KEY"
      "CLOUDFLARE_TUNNEL_TOKEN"
      "TUNNEL_TOKEN"
      "SSH_AUTH_SOCK"
      "DBUS_SESSION_BUS_ADDRESS"
      "GIT_ASKPASS"
      "GIT_CREDENTIAL_HELPER"
      "HTTP_PROXY"
      "HTTPS_PROXY"
      "ALL_PROXY"
      "http_proxy"
      "https_proxy"
      "all_proxy"
      "AWS_ACCESS_KEY_ID"
      "AWS_SECRET_ACCESS_KEY"
      "RESTIC_PASSWORD"
      "SOPS_AGE_KEY_FILE"
      "NIX_CONFIG"
      "NIX_PATH"
    ];

    ProtectSystem = "strict";
    ProtectHome = true;
    ReadWritePaths = [ workspace agentHome jobs ];
    InaccessiblePaths = [
      "-/var/lib/dsh/home"
      "-/var/log/dsh"
      "-/var/lib/vaultwarden"
      "-/var/lib/restic"
      "-/var/cache/restic"
      "-/var/backup"
      "-/var/backups"
      "-/run/secrets"
      "-/run/secrets-rendered"
      "-/run/credentials"
      "-/var/lib/sops-nix"
      "-/etc/ssh"
      "-/run/dbus"
      "-/run/postgresql"
      "-/run/mysqld"
    ];

    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    CapabilityBoundingSet = "";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
    RestrictSUIDSGID = true;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    SystemCallFilter = [ "@system-service" ];
    SystemCallErrorNumber = "EPERM";
    SocketBindDeny = "any";

    MemoryMax = "2G";
    CPUQuota = "100%";
    TasksMax = 128;
    TimeoutStartSec = "20min";
    TimeoutStopSec = "30s";
    KillMode = "control-group";
    StandardInput = "null";
    StandardOutput = "null";
    StandardError = "null";
  };
in
{
  options.dot.hopper.dsh.codingAgents = {
    enable = lib.mkEnableOption "Hopper 上由独立系统身份运行的本机编码 agent";

    codex = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "允许固定调度器调用锁定 nixpkgs 中的 Codex CLI。";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.codex;
        description = "经审查的 Codex CLI Nix 包；默认使用服务器 Flake 锁定的 nixpkgs。";
      };
    };

    selfTest.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "创建仅用于验证同一 systemd 沙箱边界的手动 self-test 单元。";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = dshCfg.enable;
        message = "本机编码 agent 依赖 Hopper DSH 主服务启用。";
      }
      {
        assertion = config.dot.services.resticBackup.enable;
        message = "本机编码 agent 启用前必须启用 Hopper 本地 Restic 备份。";
      }
      {
        assertion = cfg.codex.enable;
        message = "首版只支持 Codex，codingAgents.enable 必须同时启用 Codex。";
      }
      {
        assertion = false;
        message = "Codex DSH 插件适配器尚未按锁定 DSH API 实现并验收，编码 agent 首版禁止启用。";
      }
    ];

    users.groups.dsh-workspace = { };
    users.groups.dsh-agent = { };

    users.users.dsh.extraGroups = lib.mkAfter [ "dsh-workspace" ];
    users.users.dsh-agent = {
      isSystemUser = true;
      group = "dsh-agent";
      extraGroups = [ "dsh-workspace" ];
      home = agentHome;
      createHome = false;
      hashedPassword = "!";
      shell = pkgs.bashInteractive;
      description = "Restricted local coding-agent identity for Hopper DSH";
    };

    systemd.tmpfiles.rules = [
      "d ${agentHome} 0700 dsh-agent dsh-agent -"
      "d ${agentHome}/codex 0700 dsh-agent dsh-agent -"
      "d ${agentHome}/config 0700 dsh-agent dsh-agent -"
      "d ${agentHome}/data 0700 dsh-agent dsh-agent -"
      "d ${agentHome}/cache 0700 dsh-agent dsh-agent -"
      "d ${agentHome}/queue 0700 dsh-agent dsh-agent -"
      "d ${agentHome}/jobs 0700 dsh-agent dsh-agent -"
      "d ${workspace} 2770 dsh dsh-workspace -"
      "d ${jobs} 2770 dsh dsh-workspace -"
      "d ${jobs}/codex 2770 dsh dsh-workspace -"
      "d ${jobs}/codex/claimed 2770 dsh dsh-workspace -"
      "d ${jobs}/codex/results 2770 dsh dsh-workspace -"
      "d ${jobs}/codex/cancel 2770 dsh dsh-workspace -"
    ];

    # Defense in depth for future backup path expansion. The agent home holds
    # auth.json and all provider state and must never enter either backup copy.
    services.restic.backups.hopper-local.exclude = lib.mkAfter [ agentHome ];

    systemd.slices.dsh-coding = {
      description = "Hopper local coding-agent resource budget";
      sliceConfig = {
        MemoryMax = "4G";
        CPUQuota = "200%";
        TasksMax = 256;
      };
    };

    environment.etc = lib.mkIf cfg.codex.enable {
      "dsh-agent-codex".source = "${cfg.codex.package}/bin/codex";
    };

    systemd.services."dsh-coding@" = lib.mkIf cfg.codex.enable {
      description = "Hopper DSH controlled Codex task %i";
      unitConfig.ConditionPathExists = "!/run/dsh-backup-session/agents-paused";
      # No wantedBy: only the fixed path unit or an administrator can start it.
      serviceConfig = commonServiceConfig // {
        ExecStart = "${pkgs.python3}/bin/python3 ${./dsh-agent-runner.py} --commands ${commands} --tool %i";
      };
    };

    systemd.paths.dsh-coding-codex = lib.mkIf cfg.codex.enable {
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = "!/run/dsh-backup-session/agents-paused";
      pathConfig = {
        PathExists = "${jobs}/codex/request.json";
        Unit = "dsh-coding@codex.service";
        TriggerLimitIntervalSec = "60s";
        TriggerLimitBurst = 5;
      };
    };

    systemd.services.dsh-coding-self-test = lib.mkIf cfg.selfTest.enable {
      description = "Hopper DSH coding-agent sandbox boundary self-test";
      unitConfig.ConditionPathExists = "!/run/dsh-backup-session/agents-paused";
      serviceConfig = commonServiceConfig // {
        ExecStart = "${pkgs.python3}/bin/python3 ${./dsh-agent-runner.py} --self-test";
        TimeoutStartSec = "2min";
      };
    };


  };
}
