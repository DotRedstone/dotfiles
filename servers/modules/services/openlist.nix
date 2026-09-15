# ---
# Module: Native OpenList
# Description: Native OpenList and authenticated loopback-only Aria2 services with persistent state
# Scope: System
# Notes:
# - OpenList credentials and storage-driver tokens remain inside its restored SQLite database.
# - OpenList's restored database must use the same Aria2 RPC secret from SOPS.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.openlist;
in
{
  options.dot.services.openlist.enable = lib.mkEnableOption "the native OpenList service";

  config = lib.mkIf cfg.enable {
    sops.secrets."aria2/rpc_secret" = {
      owner = "aria2";
      group = "aria2";
      mode = "0400";
      restartUnits = [ "aria2.service" ];
    };

    users = {
      groups.openlist = { };
      users = {
        openlist = {
          isSystemUser = true;
          group = "openlist";
          extraGroups = [ "aria2" ];
          home = "/var/lib/openlist";
        };

        aria2.extraGroups = [ "openlist" ];
      };
    };

    services.aria2 = {
      enable = true;
      openPorts = false;
      rpcSecretFile = config.sops.secrets."aria2/rpc_secret".path;
      downloadDirPermission = "0770";
      serviceUMask = "0007";
      settings = {
        dir = "/var/lib/openlist/downloads";
        "rpc-listen-all" = false;
        "rpc-listen-port" = 6800;
        "disable-ipv6" = true;
        continue = true;
      };
    };

    systemd.services.openlist = {
      description = "OpenList file aggregation service";
      after = [
        "aria2.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        ffmpeg-headless
        p7zip
        unzip
      ];

      serviceConfig = {
        Type = "simple";
        User = "openlist";
        Group = "openlist";
        SupplementaryGroups = [ "aria2" ];
        StateDirectory = "openlist";
        StateDirectoryMode = "0750";
        WorkingDirectory = "/var/lib/openlist";
        Environment = "OPENLIST_ADDR=127.0.0.1";
        ExecStart = "${lib.getExe pkgs.openlist} server --data /var/lib/openlist --log-std";
        Restart = "on-failure";
        RestartSec = "5s";

        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictSUIDSGID = true;
      };
    };
  };
}
