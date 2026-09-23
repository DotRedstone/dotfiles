# ---
# Module: Hopper Services
# Description: Host-specific native application, database, proxy, and monitoring wiring
# Scope: Host
# Notes:
# - Docker and containerd are intentionally absent from this host.
# ---

{ ... }: {
  dot.services = {
    komariAgent.enable = true;
    mongodb.enable = true;
    mysql.enable = true;
    navidrome.enable = true;
    # Relay signed official packages into Singapore once, then serve cache hits to
    # the workstation and other NixOS hosts from Hopper's local disk.
    nixCacheRelay.enable = true;
    openlist.enable = true;
    postgresql.enable = true;
    redis.enable = true;
    resticBackup.enable = true;
    resticReceiver = {
      enable = true;
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFAKBkZaDY7O0b+Z3PuW4TVXg8NOpADF6YGkC2EqY7WA restic-conduit-to-hopper"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWQ6LPq45Hr6ZMdlGZq0X929eVk9YnZ07yfNFtj06/F restic-target-to-hopper"
      ];
    };
    rustfs.enable = true;

    xrayNode = {
      enable = true;
      webSocketPort = 20001;
      webSocketClientCount = 2;
      realityPort = 20002;
      realityListenAddress = "0.0.0.0";
      realityTarget = "www.nvidia.com:443";
      realityServerName = "www.nvidia.com";
    };

    xraySubscriptions = {
      enable = true;
      hostName = "sg-node.540123.xyz";
      publicAddress = "140.245.62.36";
      entryNames = [
        "websocket"
        "reality"
      ];
    };
  };
}
