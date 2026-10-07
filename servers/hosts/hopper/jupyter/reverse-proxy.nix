# ---
# Module: Hopper Jupyter Reverse Proxy
# Description: Nginx virtual host configuration for JupyterHub
# Scope: Host
# ---

{ ... }: {
  services.nginx.virtualHosts."jupyter.bdot.in" = {
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
}
