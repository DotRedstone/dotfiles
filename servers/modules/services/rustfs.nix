# ---
# Module: Native RustFS
# Description: Native loopback-only RustFS object storage with runtime-decrypted credentials
# Scope: System
# Notes:
# - Existing S3 access keys are preserved because clients may depend on them.
# ---

{ config, lib, ... }:

let
  cfg = config.dot.services.rustfs;
in
{
  options.dot.services.rustfs.enable = lib.mkEnableOption "the native RustFS object store";

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "rustfs/access_key".restartUnits = [ "rustfs.service" ];
      "rustfs/secret_key".restartUnits = [ "rustfs.service" ];
    };

    sops.templates."rustfs.env" = {
      owner = "rustfs";
      group = "rustfs";
      mode = "0400";
      content = ''
        RUSTFS_ACCESS_KEY=${config.sops.placeholder."rustfs/access_key"}
        RUSTFS_SECRET_KEY=${config.sops.placeholder."rustfs/secret_key"}
      '';
    };

    services.rustfs = {
      enable = true;
      environmentFile = config.sops.templates."rustfs.env".path;
      settings = {
        RUSTFS_VOLUMES = "/var/lib/rustfs";
        RUSTFS_ADDRESS = "127.0.0.1:9000";
        RUSTFS_CONSOLE_ADDRESS = "127.0.0.1:9001";
        RUSTFS_CONSOLE_ENABLE = "true";
        RUSTFS_CORS_ALLOWED_ORIGINS = "*";
        RUSTFS_CONSOLE_CORS_ALLOWED_ORIGINS = "*";
        RUSTFS_OBS_ENVIRONMENT = "production";
        RUSTFS_OBS_LOGGER_LEVEL = "warn";
      };
    };

    systemd.services.rustfs = {
      after = [ "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
    };
  };
}
