# ---
# Module: Hopper Reverse Proxy
# Description: Nginx virtual hosts for retained applications and the private JupyterHub
# Scope: Host
# Notes:
# - TLS currently terminates at Cloudflare, matching the legacy HTTP-only origin vhosts.
# - RustFS API buffering is disabled so large S3 uploads stream directly to the service.
# ---

{ ... }: {
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      "music.bdot.in" = {
        serverAliases = [ "music.540123.xyz" ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:4533";
          proxyWebsockets = true;
        };
      };

      "openlist.bdot.in" = {
        serverAliases = [ "openlist-origin.bdot.in" ];
        extraConfig = "client_max_body_size 0;";
        locations."/" = {
          proxyPass = "http://127.0.0.1:5244";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
          '';
        };
      };

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

      "jupyter.bdot.in" = {
        serverAliases = [ "jupyter-origin.bdot.in" ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
          '';
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
