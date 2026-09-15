# ---
# Module: Native MongoDB
# Description: Native authenticated loopback-only MongoDB service with encrypted bootstrap credentials
# Scope: System
# Notes:
# - Migration uses logical dump and restore because the source 8.3 data files cannot be downgraded in place.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.mongodb;
  backupPrivilegeScript = pkgs.writeText "mongodb-backup-privileges.js" ''
    const fs = require("fs");
    const password = fs.readFileSync(
      "${config.sops.secrets."mongodb/bootstrap_password".path}",
      "utf8",
    ).trim();
    const admin = db.getSiblingDB("admin");

    if (!admin.auth("root", password)) {
      throw new Error("MongoDB backup-role bootstrap authentication failed");
    }

    const result = admin.runCommand({
      grantRolesToUser: "root",
      roles: [
        { role: "backup", db: "admin" },
        { role: "restore", db: "admin" },
      ],
    });

    if (!result.ok) {
      throw new Error("MongoDB backup-role bootstrap failed: " + JSON.stringify(result));
    }
  '';
in
{
  options.dot.services.mongodb.enable = lib.mkEnableOption "the native MongoDB database";

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfreePredicate = package: lib.getName package == "mongodb-ce";

    sops.secrets."mongodb/bootstrap_password" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "mongodb.service" ];
    };

    services.mongodb = {
      enable = true;
      package = pkgs.mongodb-ce;
      mongoshPackage = pkgs.mongosh;
      bind_ip = "127.0.0.1";
      enableAuth = true;
      initialRootPasswordFile = config.sops.secrets."mongodb/bootstrap_password".path;
    };

    # NixOS' initial root account predates MongoDB's dedicated backup role.
    # Reconcile existing databases as well as new installations without putting
    # the password in a command line or the Nix store.
    systemd.services.mongodb-backup-privileges = {
      description = "Grant MongoDB root account backup and restore privileges";
      requires = [ "mongodb.service" ];
      after = [ "mongodb.service" ];
      path = [ pkgs.mongosh ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        mongosh --quiet --norc --file ${backupPrivilegeScript} > /dev/null
      '';
    };
  };
}
