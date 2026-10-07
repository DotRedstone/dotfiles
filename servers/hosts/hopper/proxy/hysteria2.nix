# ---
# Module: Hopper Hysteria2 Node
# Description: Hysteria2 egress proxy node and ACME validation reverse proxy
# Scope: Host
# ---

{ ... }: {
  dot.services.hysteria2Node = {
    enable = true;
    domain = "hy2-sg.bdot.in";
    acmeEmail = "admin@bdot.in";
  };

  services.nginx.virtualHosts."hy2-sg.bdot.in" = {
    locations."/.well-known/acme-challenge/" = {
      proxyPass = "http://127.0.0.1:8888";
      extraConfig = "proxy_buffering off;";
    };
    locations."/".return = "404";
  };
}
