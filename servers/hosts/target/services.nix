# ---
# Module: Target Services
# Description: EasyTier listener, internal game forwarding, and isolated Restic backup wiring
# Scope: Host
# ---

{ ... }: {
  dot.services = {
    easytier = {
      enable = true;
      ipv4 = "10.8.0.3";
      hostname = "tencent-node";
      # Match the local router's authenticated EasyTier identity.  The legacy
      # Aliyun relay accepts a different configuration shape, so it is not a
      # credential source for new nodes.
      useNetworkSecret = true;
      peers = [ "tcp://47.110.239.66:11010" ];
      noListener = false;
      listenPort = 11010;
    };

    resticClient = {
      enable = true;
      receiverHost = "140.245.62.36";
      receiverHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmQulEZ0fvRUFaP4tH4XaQu047CwW9KUjd8sqGcmc1p";
      repositoryName = "target";
      paths = [ "/var/lib/easytier" ];
    };
  };

  services.nginx = {
    enable = true;
    streamConfig = ''
      # The legacy Aliyun relay owns the working EasyTier route into the home
      # LAN.  Keep this Tencent endpoint as a verified alternate ingress
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
