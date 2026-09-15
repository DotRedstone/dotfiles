# ---
# Module: Restic SFTP Client
# Description: Sends one host's selected state to its isolated Restic repository on the backup receiver
# Scope: System
# Notes:
# - Each host must use a different SSH key, repository password, and repository name.
# - Database exports belong in a host-specific prepare command, not in this generic transport module.
# ---

{
  config,
  lib,
  ...
}:
let
  cfg = config.dot.services.resticClient;
  privateKeyFile = config.sops.secrets.${cfg.privateKeySecret}.path;
  passwordFile = config.sops.secrets.${cfg.repositoryPasswordSecret}.path;
in
{
  options.dot.services.resticClient = {
    enable = lib.mkEnableOption "a Restic client for the dedicated Hopper SFTP receiver";

    receiverHost = lib.mkOption {
      type = lib.types.str;
      description = "IP address or DNS name of the SFTP backup receiver.";
    };

    receiverHostKey = lib.mkOption {
      type = lib.types.str;
      description = "Pinned SSH public host key for the backup receiver.";
    };

    repositoryName = lib.mkOption {
      type = lib.types.str;
      description = "Unique repository directory below the receiver's isolated repositories directory.";
    };

    privateKeySecret = lib.mkOption {
      type = lib.types.str;
      default = "restic/client_ssh_private_key";
      description = "SOPS key containing this client's dedicated SSH private key.";
    };

    repositoryPasswordSecret = lib.mkOption {
      type = lib.types.str;
      default = "restic/repository_password";
      description = "SOPS key containing this client's unique Restic repository password.";
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host state paths to include in the backup.";
    };

    timerConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        OnCalendar = "*-*-* 01:30:00";
        RandomizedDelaySec = "15m";
        Persistent = true;
      };
      description = "Systemd timer configuration for this host's source backup.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.paths != [ ];
        message = "dot.services.resticClient.paths must contain at least one state path.";
      }
    ];

    sops.secrets = {
      ${cfg.privateKeySecret} = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      ${cfg.repositoryPasswordSecret} = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    services.openssh.knownHosts.hopper-restic = {
      hostNames = [ cfg.receiverHost ];
      publicKey = cfg.receiverHostKey;
    };

    programs.ssh.extraConfig = ''
      Host hopper-restic
        HostName ${cfg.receiverHost}
        User restic
        IdentityFile ${privateKeyFile}
        IdentitiesOnly yes
        BatchMode yes
        StrictHostKeyChecking yes
        UserKnownHostsFile /etc/ssh/ssh_known_hosts
        ServerAliveInterval 60
        ServerAliveCountMax 240
    '';

    sops.templates."restic-client.env" = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        RESTIC_REPOSITORY=sftp:hopper-restic:/repositories/${cfg.repositoryName}
        RESTIC_PASSWORD_FILE=${passwordFile}
      '';
    };

    services.restic.backups.${cfg.repositoryName} = {
      environmentFile = config.sops.templates."restic-client.env".path;
      initialize = true;
      paths = cfg.paths;
      timerConfig = cfg.timerConfig;
      extraBackupArgs = [ "--tag=${cfg.repositoryName}" ];
      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
      ];
    };
  };
}
