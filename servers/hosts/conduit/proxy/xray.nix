# ---
# Module: Conduit Xray Node
# Description: Xray egress proxy node with WebSocket, CDN, and Reality/Vision endpoints
# Scope: Host
# ---

{ config, ... }: {
  dot.services = {
    xrayNode = {
      enable = true;
      managedAccounts = config.dot.proxyAccounts.accounts;
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
  };
}
