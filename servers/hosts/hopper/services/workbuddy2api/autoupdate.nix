# ---
# Module: Hopper WorkBuddy2API 每日自动升级
# Description: systemd timer 驱动 /var/lib/dsh/workspaces/qq/wb2api/update.sh
#              （check -> bump -> nix build 验证 -> commit/push -> 投 deploy-request）
# Scope: Host
# Notes:
#   - 只负责定时触发，不直接 switch；真正的 build+switch 仍由 root 的 hopper-deploy.service 执行。
#   - 脚本逻辑不在此处重写，模块只提供运行环境（PATH / HOME / 工作目录 / 超时）。
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.hopper.workbuddy2api;

  # 脚本目录与 dsh 家目录（git 身份与 GitHub SSH key 都在 HOME 下）
  scriptDir = "/var/lib/dsh/workspaces/qq/wb2api";
  dshHome = "/var/lib/dsh/home";

  # NixOS 上 systemd 单元的默认 PATH 几乎是空的（只有 /usr/bin/env 可用），
  # 脚本里 command -v nix/git/curl/jq/python3/flock 全靠这份显式列表。
  runtimePath = with pkgs; [
    bash
    coreutils
    gnugrep
    gnused
    gawk
    diffutils # cmp：bump.sh 失败时比对备份与 package.nix

    git
    openssh
    curl
    jq
    python3
    nix
    util-linux # flock
  ];
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.wb2api-autoupdate = {
      description = "WorkBuddy2API 每日检查并通过 deploy-request 升级 upstream 版本（不直接 switch）";

      unitConfig = {
        # 一轮可能要下载 + 构建，失败不要卡住下一轮
        StartLimitIntervalSec = 0;
      };

      serviceConfig = {
        Type = "oneshot";
        User = "dsh";
        Group = "dsh";
        WorkingDirectory = scriptDir;
        # bump.sh 会真下载两个平台的 zip 并做 nix build 验证，留足时间
        TimeoutStartSec = "30min";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "wb2api-autoupdate";
        ExecStart = "/usr/bin/env bash ${scriptDir}/update.sh";
      };

      path = runtimePath;

      environment = {
        HOME = dshHome;
        GIT_SSH_COMMAND = "${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=accept-new";
      };

      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };

    systemd.timers.wb2api-autoupdate = {
      description = "每日 05:17 触发 WorkBuddy2API 自动升级检查";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 05:17:00";
        RandomizedDelaySec = "30min";
        Persistent = true;
        Unit = "wb2api-autoupdate.service";
      };
    };
  };
}
