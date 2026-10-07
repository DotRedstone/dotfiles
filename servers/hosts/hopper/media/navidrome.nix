# ---
# Module: Hopper Navidrome Music Server
# Description: Navidrome personal music streaming service and Nginx reverse proxy
# Scope: Host
# ---

{ ... }: {
  dot.services.navidrome.enable = true;

  services.nginx.virtualHosts."music.bdot.in" = {
    serverAliases = [ "music.540123.xyz" ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:4533";
      proxyWebsockets = true;
    };
  };
}
