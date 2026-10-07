# ---
# Module: Conduit Services
# Description: Host-specific mesh, Xray, subscription, and monitoring wiring
# Scope: Host
# ---

{ ... }: {
  dot.services = {
    resticClient = {
      enable = true;
      receiverHost = "140.245.62.36";
      receiverHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmQulEZ0fvRUFaP4tH4XaQu047CwW9KUjd8sqGcmc1p";
      repositoryName = "conduit";
      paths = [ "/var/lib/easytier" ];
    };

    komariAgent.enable = true;

    xrayNode = {
      enable = true;
      webSocketPort = 20001;
      realityPort = 20002;
      realityListenAddress = "107.174.1.97";
      realityTarget = "www.nvidia.com:443";
      realityServerName = "www.nvidia.com";
      # Grey-release identity; the established Reality client remains unchanged.
      realityVisionEnable = true;
    };

    xrayCdnWebSocket = {
      enable = true;
      serverName = "la-cdn.bdot.in";
    };

    xraySubscriptions = {
      enable = true;
      hostName = "la-node.540123.xyz";
      publicAddress = "107.174.1.97";
      entryNames = [
        "websocket"
        "reality"
        "cdn"
      ];
      entryExpectedAddresses.cdn = "la-cdn.bdot.in";
    };
  };
}
