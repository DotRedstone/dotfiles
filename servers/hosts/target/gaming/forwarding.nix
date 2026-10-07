# ---
# Module: Target Game Traffic Forwarding
# Description: Nginx stream proxy and firewall rules for Minecraft and voice backends
# Scope: Host
# ---

{ ... }: {
  services.nginx = {
    enable = true;
    streamConfig = ''
      # The legacy Aliyun relay owns the working EasyTier route into the home
      # LAN. Keep this Tencent endpoint as a verified alternate ingress
      # instead of sending game traffic to an unroutable private address.
      upstream minecraft_backend { server 47.110.239.66:25565; }
      server {
        listen 25565;
        proxy_pass minecraft_backend;
      }

      upstream voice_backend { server 47.110.239.66:24454; }
      server {
        listen 24454 udp reuseport;
        proxy_pass voice_backend;
      }
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [ 25565 ];
    allowedUDPPorts = [ 24454 ];
  };
}
