# ---
# Module: Native PostgreSQL
# Description: Native loopback-only PostgreSQL 18 database service
# Scope: System
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.postgresql;
in
{
  options.dot.services.postgresql.enable = lib.mkEnableOption "the native PostgreSQL database";

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_18;
      settings = {
        listen_addresses = lib.mkForce "127.0.0.1";
        password_encryption = "scram-sha-256";
      };
    };
  };
}
