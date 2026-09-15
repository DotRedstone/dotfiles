# ---
# Module: Restic SFTP Receiver
# Description: Restricts a dedicated SSH account to isolated Restic repositories over internal SFTP
# Scope: System
# Notes:
# - This host receives backups from other machines; it is not an off-site backup of itself.
# - Add one dedicated client public key at a time through authorizedKeys.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dot.services.resticReceiver;
in {
  options.dot.services.resticReceiver = {
    enable = lib.mkEnableOption "the locked-down Restic SFTP receiver";

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Public keys permitted to write Restic repositories through the restricted SFTP account.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.restic = { };

    users.users.restic = {
      isSystemUser = true;
      group = "restic";
      home = "/var/lib/restic";
      createHome = false;
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    # ChrootDirectory itself must remain root-owned; clients receive write
    # access only to repositories below it.
    systemd.tmpfiles.rules = [
      "d /var/lib/restic 0755 root root -"
      "d /var/lib/restic/repositories 0750 restic restic -"
    ];

    services.openssh.settings.AllowUsers = lib.mkAfter [ "restic" ];
    services.openssh.extraConfig = ''
      Match User restic
        ChrootDirectory /var/lib/restic
        ForceCommand internal-sftp -d /repositories
        AllowTcpForwarding no
        PermitTTY no
        X11Forwarding no
    '';
  };
}
