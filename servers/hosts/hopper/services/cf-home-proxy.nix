# ---
# Module: Hopper Cloudflare Home Proxy Bridge
# Description: Background access tcp bridge to home router proxy
# Scope: Host
# ---

{ pkgs, ... }: {
  systemd.services.cf-home-proxy = {
    description = "Cloudflare Tunnel Access TCP bridge to home router proxy";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared access tcp --hostname home-proxy.bdot.in --url 127.0.0.1:17890";
      Restart = "always";
      RestartSec = "5s";
      User = "dot";
    };
  };
}
