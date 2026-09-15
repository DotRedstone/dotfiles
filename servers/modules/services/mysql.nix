# ---
# Module: Native MySQL
# Description: Native loopback-only MySQL 8.4 database service
# Scope: System
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.mysql;
in
{
  options.dot.services.mysql.enable = lib.mkEnableOption "the native MySQL database";

  config = lib.mkIf cfg.enable {
    services.mysql = {
      enable = true;
      package = pkgs.mysql84;
      settings.mysqld = {
        bind-address = "127.0.0.1";
        host-cache-size = 0;
        lower_case_table_names = 1;
        mysqlx-bind-address = "127.0.0.1";
        skip-name-resolve = true;
      };
    };
  };
}
