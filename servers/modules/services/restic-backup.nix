# ---
# Module: Hopper Restic Backup
# Description: Creates consistent Hopper service backups locally and mirrors snapshots to Cloudflare R2
# Scope: System
# Notes:
# - Database state is exported logically; do not add live database directories to paths.
# - The local repository is a fast recovery copy, while R2 is the independent off-site copy.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dot.services.resticBackup;
  stagingDirectory = "/var/lib/restic/staging/hopper";
  localRepository = "/var/lib/restic/repositories/hopper";
  passwordFile = config.sops.secrets."restic/hopper_repository_password".path;
in
{
  options.dot.services.resticBackup = {
    enable = lib.mkEnableOption "the Hopper local-to-R2 Restic backup pipeline";

    r2Bucket = lib.mkOption {
      type = lib.types.str;
      default = "dot-restic-backups";
      description = "Dedicated Cloudflare R2 bucket holding off-site Restic repositories.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.mongodb-tools ];

    sops.secrets = {
      "restic/hopper_repository_password" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "restic/conduit_repository_password" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "restic/repeater_repository_password" = {
        owner = "root";
        # The import job runs as the restricted Restic receiver user; keep the
        # credential otherwise unreadable while allowing that single service.
        group = "restic";
        mode = "0440";
      };
      "restic/target_repository_password" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "restic/repeater_export_ssh_private_key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "restic/r2_access_key_id" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "restic/r2_secret_access_key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "restic/r2_endpoint" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    sops.templates = {
      "restic-hopper-r2.env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder."restic/r2_access_key_id"}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."restic/r2_secret_access_key"}
          AWS_DEFAULT_REGION=auto
          RESTIC_REPOSITORY=s3:${config.sops.placeholder."restic/r2_endpoint"}/${cfg.r2Bucket}/hopper
          RESTIC_PASSWORD_FILE=${passwordFile}
        '';
      };

      "restic-conduit-r2.env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder."restic/r2_access_key_id"}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."restic/r2_secret_access_key"}
          AWS_DEFAULT_REGION=auto
          RESTIC_REPOSITORY=s3:${config.sops.placeholder."restic/r2_endpoint"}/${cfg.r2Bucket}/conduit
          RESTIC_PASSWORD_FILE=${config.sops.secrets."restic/conduit_repository_password".path}
        '';
      };

      "restic-repeater-r2.env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder."restic/r2_access_key_id"}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."restic/r2_secret_access_key"}
          AWS_DEFAULT_REGION=auto
          RESTIC_REPOSITORY=s3:${config.sops.placeholder."restic/r2_endpoint"}/${cfg.r2Bucket}/repeater
          RESTIC_PASSWORD_FILE=${config.sops.secrets."restic/repeater_repository_password".path}
        '';
      };

      "restic-target-r2.env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder."restic/r2_access_key_id"}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."restic/r2_secret_access_key"}
          AWS_DEFAULT_REGION=auto
          RESTIC_REPOSITORY=s3:${config.sops.placeholder."restic/r2_endpoint"}/${cfg.r2Bucket}/target
          RESTIC_PASSWORD_FILE=${config.sops.secrets."restic/target_repository_password".path}
        '';
      };

      "restic-repeater-export-known-hosts" = {
        owner = "root";
        group = "root";
        mode = "0444";
        content = ''
          47.110.239.66 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPaj8MDtlnNGmXqMToDFV3CsjxeMq2FO9w8yP2W8gsMV
        '';
      };

    };

    services.restic.backups.hopper-local = {
      repository = localRepository;
      passwordFile = passwordFile;
      initialize = true;
      timerConfig = null;
      paths = [
        "/var/lib/openlist"
        "/var/lib/navidrome"
        "/var/lib/rustfs"
        stagingDirectory
      ];
      extraBackupArgs = [
        "--tag=hopper"
        "--tag=local"
      ];
      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
      ];
      backupPrepareCommand = ''
        set -euo pipefail
        umask 077
        rm -rf ${stagingDirectory}
        install -d -m 0700 ${stagingDirectory}

        ${pkgs.mysql84}/bin/mysqldump \
          --all-databases \
          --single-transaction \
          --routines \
          --events \
          --triggers \
          --set-gtid-purged=OFF \
          > ${stagingDirectory}/mysql.sql

        ${pkgs.util-linux}/bin/runuser -u postgres -- \
          ${pkgs.postgresql_18}/bin/pg_dumpall \
          --clean \
          --if-exists \
          > ${stagingDirectory}/postgresql.sql

        mongodb_dump_config="$(mktemp /run/restic-backups-hopper-local/mongodump.XXXXXX.json)"
        trap 'rm -f "$mongodb_dump_config"' EXIT
        ${pkgs.jq}/bin/jq -n \
          --rawfile password ${config.sops.secrets."mongodb/bootstrap_password".path} \
          '{ password: $password }' \
          > "$mongodb_dump_config"
        ${pkgs.mongodb-tools}/bin/mongodump \
          --config "$mongodb_dump_config" \
          --host 127.0.0.1 \
          --username root \
          --authenticationDatabase admin \
          --archive=${stagingDirectory}/mongodb.archive.gz \
          --gzip
        rm -f "$mongodb_dump_config"
        trap - EXIT

        REDISCLI_AUTH="$(<${config.sops.secrets."redis/password".path})" \
          ${pkgs.redis}/bin/redis-cli --rdb ${stagingDirectory}/redis.rdb
      '';
      backupCleanupCommand = ''
        rm -rf ${stagingDirectory}
      '';
    };

    systemd.services.restic-backups-hopper-local = {
      requires = [ "mongodb-backup-privileges.service" ];
      after = [ "mongodb-backup-privileges.service" ];
    };

    systemd.services.restic-mirror-hopper-to-r2 = {
      description = "Mirror Hopper Restic snapshots to Cloudflare R2";
      requires = [ "restic-backups-hopper-local.service" ];
      after = [
        "network-online.target"
        "mongodb-backup-privileges.service"
        "restic-backups-hopper-local.service"
      ];
      wants = [ "network-online.target" ];
      path = [ pkgs.restic ];
      environment.RESTIC_CACHE_DIR = "/var/cache/restic-mirror-hopper-to-r2";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates."restic-hopper-r2.env".path;
        CacheDirectory = "restic-mirror-hopper-to-r2";
        CacheDirectoryMode = "0700";
        PrivateTmp = true;
      };
      script = ''
        set -euo pipefail

        if ! restic cat config > /dev/null 2>&1; then
          restic init \
            --from-repo ${localRepository} \
            --from-password-file ${passwordFile} \
            --copy-chunker-params
        fi

        restic copy \
          --from-repo ${localRepository} \
          --from-password-file ${passwordFile}

        restic forget --prune \
          --keep-daily 14 \
          --keep-weekly 8 \
          --keep-monthly 12
      '';
    };

    systemd.timers.restic-mirror-hopper-to-r2 = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03:30:00";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
    };

    systemd.services.restic-check-hopper-r2 = {
      description = "Sample-check Hopper's off-site Restic repository";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.restic ];
      environment.RESTIC_CACHE_DIR = "/var/cache/restic-check-hopper-r2";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates."restic-hopper-r2.env".path;
        CacheDirectory = "restic-check-hopper-r2";
        CacheDirectoryMode = "0700";
        PrivateTmp = true;
      };
      script = ''
        set -euo pipefail
        restic check --read-data-subset=5%
      '';
    };

    systemd.timers.restic-check-hopper-r2 = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        RandomizedDelaySec = "12h";
        Persistent = true;
      };
    };

    systemd.services.restic-mirror-conduit-to-r2 = {
      description = "Mirror Conduit Restic snapshots to Cloudflare R2";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.restic ];
      environment.RESTIC_CACHE_DIR = "/var/cache/restic-mirror-conduit-to-r2";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates."restic-conduit-r2.env".path;
        CacheDirectory = "restic-mirror-conduit-to-r2";
        CacheDirectoryMode = "0700";
        PrivateTmp = true;
      };
      script = ''
        set -euo pipefail

        if ! restic cat config > /dev/null 2>&1; then
          restic init \
            --from-repo /var/lib/restic/repositories/conduit \
            --from-password-file ${config.sops.secrets."restic/conduit_repository_password".path} \
            --copy-chunker-params
        fi

        restic copy \
          --from-repo /var/lib/restic/repositories/conduit \
          --from-password-file ${config.sops.secrets."restic/conduit_repository_password".path}

        restic forget --prune \
          --keep-daily 14 \
          --keep-weekly 8 \
          --keep-monthly 12
      '';
    };

    systemd.timers.restic-mirror-conduit-to-r2 = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03:50:00";
        RandomizedDelaySec = "15m";
        Persistent = true;
      };
    };

    systemd.services.restic-check-conduit-r2 = {
      description = "Sample-check Conduit's off-site Restic repository";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.restic ];
      environment.RESTIC_CACHE_DIR = "/var/cache/restic-check-conduit-r2";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates."restic-conduit-r2.env".path;
        CacheDirectory = "restic-check-conduit-r2";
        CacheDirectoryMode = "0700";
        PrivateTmp = true;
      };
      script = ''
        set -euo pipefail
        restic check --read-data-subset=5%
      '';
    };

    systemd.timers.restic-check-conduit-r2 = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        RandomizedDelaySec = "12h";
        Persistent = true;
      };
    };

    systemd.services.restic-mirror-target-to-r2 = {
      description = "Mirror Target Restic snapshots to Cloudflare R2";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.restic ];
      environment.RESTIC_CACHE_DIR = "/var/cache/restic-mirror-target-to-r2";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates."restic-target-r2.env".path;
        CacheDirectory = "restic-mirror-target-to-r2";
        CacheDirectoryMode = "0700";
        PrivateTmp = true;
      };
      script = ''
        set -euo pipefail
        if ! restic cat config > /dev/null 2>&1; then
          restic init \
            --from-repo /var/lib/restic/repositories/target \
            --from-password-file ${config.sops.secrets."restic/target_repository_password".path} \
            --copy-chunker-params
        fi

        restic copy \
          --from-repo /var/lib/restic/repositories/target \
          --from-password-file ${config.sops.secrets."restic/target_repository_password".path}

        restic forget --prune \
          --keep-daily 14 \
          --keep-weekly 8 \
          --keep-monthly 12
      '';
    };

    systemd.timers.restic-mirror-target-to-r2 = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 04:05:00";
        RandomizedDelaySec = "15m";
        Persistent = true;
      };
    };

    systemd.services.restic-check-target-r2 = {
      description = "Sample-check Target's off-site Restic repository";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.restic ];
      environment.RESTIC_CACHE_DIR = "/var/cache/restic-check-target-r2";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates."restic-target-r2.env".path;
        CacheDirectory = "restic-check-target-r2";
        CacheDirectoryMode = "0700";
        PrivateTmp = true;
      };
      script = ''
        set -euo pipefail
        restic check --read-data-subset=5%
      '';
    };

    systemd.timers.restic-check-target-r2 = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        RandomizedDelaySec = "12h";
        Persistent = true;
      };
    };

    # Repeater has no recoverable source Flake yet. This one-shot importer
    # protects a streamed, quiesced export until the normal client module can
    # replace it after host-config recovery.
    systemd.tmpfiles.rules = [
      # The receiver account needs to traverse this parent to snapshot the
      # private Repeater staging directory; it cannot list its contents.
      "d /var/lib/restic/imports 0710 root restic -"
      "d /var/lib/restic/imports/repeater 0700 restic restic -"
    ];

    services.restic.backups.repeater-import = {
      repository = "/var/lib/restic/repositories/repeater";
      passwordFile = config.sops.secrets."restic/repeater_repository_password".path;
      initialize = true;
      timerConfig = null;
      paths = [ "/var/lib/restic/imports/repeater" ];
      extraBackupArgs = [
        "--tag=repeater"
        "--tag=imported"
      ];
      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
      ];
    };

    # Repeater's original Flake was lost.  Until that host is fully rebuilt,
    # Hopper performs a restricted pull: it briefly quiesces the two SQLite
    # writers, streams only the selected service state, then immediately
    # snapshots it as the unprivileged Restic receiver user.
    systemd.services.restic-backups-repeater-import.serviceConfig = {
      User = lib.mkForce "restic";
      Group = lib.mkForce "restic";
    };

    systemd.services.restic-export-repeater = {
      description = "Export selected Repeater state into its Restic repository";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnutar
        pkgs.gzip
        pkgs.openssh
        pkgs.systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        PrivateTmp = true;
      };
      script = ''
        set -euo pipefail

        staging=/var/lib/restic/imports/repeater
        key=${config.sops.secrets."restic/repeater_export_ssh_private_key".path}
        known_hosts=${config.sops.templates."restic-repeater-export-known-hosts".path}
        remote=(
          ssh
          -i "$key"
          -o IdentitiesOnly=yes
          -o StrictHostKeyChecking=yes
          -o UserKnownHostsFile="$known_hosts"
          -o ServerAliveInterval=15
          -o ServerAliveCountMax=4
          dot@47.110.239.66
        )

        restart_writers() {
          "''${remote[@]}" 'sudo systemctl start vaultwarden komari-server' || true
        }
        trap restart_writers EXIT

        find "$staging" -mindepth 1 -delete
        "''${remote[@]}" 'sudo systemctl stop vaultwarden komari-server'
        "''${remote[@]}" \
          'sudo tar -C / -czf - var/lib/vaultwarden var/lib/komari var/lib/easytier var/lib/nginx-certs var/lib/secrets/easytier.env' \
          | tar -xzf - -C "$staging"
        restart_writers
        trap - EXIT

        chown -R restic:restic "$staging"
        systemctl start restic-backups-repeater-import.service
        find "$staging" -mindepth 1 -delete
      '';
    };

    systemd.timers.restic-export-repeater = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 02:15:00";
        RandomizedDelaySec = "20m";
        Persistent = true;
      };
    };

    systemd.services.restic-mirror-repeater-to-r2 = {
      description = "Mirror Repeater Restic snapshots to Cloudflare R2";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.restic ];
      environment.RESTIC_CACHE_DIR = "/var/cache/restic-mirror-repeater-to-r2";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates."restic-repeater-r2.env".path;
        CacheDirectory = "restic-mirror-repeater-to-r2";
        CacheDirectoryMode = "0700";
        PrivateTmp = true;
      };
      script = ''
        set -euo pipefail

        if ! restic cat config > /dev/null 2>&1; then
          restic init \
            --from-repo /var/lib/restic/repositories/repeater \
            --from-password-file ${config.sops.secrets."restic/repeater_repository_password".path} \
            --copy-chunker-params
        fi

        restic copy \
          --from-repo /var/lib/restic/repositories/repeater \
          --from-password-file ${config.sops.secrets."restic/repeater_repository_password".path}

        restic forget --prune \
          --keep-daily 14 \
          --keep-weekly 8 \
          --keep-monthly 12
      '';
    };

    systemd.timers.restic-mirror-repeater-to-r2 = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 04:10:00";
        RandomizedDelaySec = "15m";
        Persistent = true;
      };
    };

    systemd.services.restic-check-repeater-r2 = {
      description = "Sample-check Repeater's off-site Restic repository";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.restic ];
      environment.RESTIC_CACHE_DIR = "/var/cache/restic-check-repeater-r2";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates."restic-repeater-r2.env".path;
        CacheDirectory = "restic-check-repeater-r2";
        CacheDirectoryMode = "0700";
        PrivateTmp = true;
      };
      script = ''
        set -euo pipefail
        restic check --read-data-subset=5%
      '';
    };

    systemd.timers.restic-check-repeater-r2 = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        RandomizedDelaySec = "12h";
        Persistent = true;
      };
    };
  };
}
