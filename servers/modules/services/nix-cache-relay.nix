# ---
# Module: Official Nix Cache Relay
# Description: Disk-backed Nginx relay for signed packages from cache.nixos.org
# Scope: System
# Notes:
# - This is an on-demand relay, not a builder and not an artifact backup.
# - Upstream NAR signatures remain untouched; clients continue to trust only cache.nixos.org.
# - The cache is intentionally bounded and disposable. Do not place user data here.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.nixCacheRelay;
in
{
  options.dot.services.nixCacheRelay = {
    enable = lib.mkEnableOption "an on-demand relay for the official Nix binary cache";

    cacheSize = lib.mkOption {
      type = lib.types.str;
      default = "80g";
      description = "Maximum disk space Nginx may use for cached official NARs.";
    };

    cacheInactive = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Evict entries that have not been read within this interval.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "nix-cache.${config.networking.hostName}";
      description = "Nginx server name; the virtual host is also the port 80 fallback for direct-IP clients.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/cache/nginx/nix-official 0750 nginx nginx -"
    ];

    services.nginx = {
      proxyCachePath.nix-official = {
        enable = true;
        keysZoneName = "nix_official_cache";
        keysZoneSize = "32m";
        levels = "1:2";
        useTempPath = false;
        inactive = cfg.cacheInactive;
        maxSize = cfg.cacheSize;
      };

      virtualHosts.${cfg.serverName} = {
        # Existing public applications have explicit server names. This only handles the
        # cache hostname and direct requests to Hopper's static public IP.
        default = true;

        locations."/" = {
          proxyPass = "https://cache.nixos.org";
          extraConfig = ''
            proxy_set_header Host cache.nixos.org;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_ssl_server_name on;
            proxy_ssl_name cache.nixos.org;
            proxy_ssl_verify on;
            proxy_ssl_trusted_certificate ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt;

            # NARs and narinfo records are content-addressed and signed upstream. Cache
            # them locally while keeping small failure responses short-lived.
            proxy_cache nix_official_cache;
            proxy_cache_methods GET HEAD;
            proxy_cache_key "$scheme$proxy_host$request_uri";
            proxy_cache_valid 200 301 302 30d;
            proxy_cache_valid 404 5m;
            proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
            proxy_cache_lock on;
            proxy_cache_lock_timeout 10m;
            proxy_cache_lock_age 10m;
            proxy_cache_background_update on;
            proxy_cache_revalidate on;
            proxy_ignore_headers Cache-Control Expires Set-Cookie;

            add_header X-Nix-Cache $upstream_cache_status always;
          '';
        };
      };
    };
  };
}
