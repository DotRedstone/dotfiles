# ---
# Module: Hopper OpenList Service
# Description: OpenList file indexing service and Nginx reverse proxy
# Scope: Host
# ---

{ ... }: {
  dot.services.openlist.enable = true;

  services.nginx.virtualHosts."openlist.bdot.in" = {
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
}
