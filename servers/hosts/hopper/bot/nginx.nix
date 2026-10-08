# ---
# Module: Hopper Bot Nginx Proxy
# Description: Reverse proxy for AstrBot web management interface
# Scope: Host
# ---

{ ... }: {
  services.nginx.virtualHosts."astrbot.bdot.in" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:6185";
      proxyWebsockets = true;
    };
  };
}
