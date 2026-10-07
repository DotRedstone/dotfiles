# ---
# Module: Hopper RustFS Object Storage
# Description: RustFS S3-compatible storage service and public API reverse proxy
# Scope: Host
# ---

{ ... }: {
  dot.services.rustfs.enable = true;

  services.nginx.virtualHosts = {
    "oss.bdot.in" = {
      extraConfig = "client_max_body_size 0;";
      locations."/" = {
        proxyPass = "http://127.0.0.1:9000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
        '';
      };
    };

    "rustfs.bdot.in".locations."/" = {
      proxyPass = "http://127.0.0.1:9001";
      proxyWebsockets = true;
    };
  };
}
