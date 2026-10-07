# ---
# Module: Hopper Xray Node
# Description: Xray egress proxy node with WebSocket and Reality/Vision endpoints
# Scope: Host
# ---

{ ... }: {
  dot.services.xrayNode = {
    enable = true;
    webSocketPort = 20001;
    webSocketClientCount = 2;
    realityPort = 20002;
    realityListenAddress = "0.0.0.0";
    realityTarget = "www.nvidia.com:443";
    realityServerName = "www.nvidia.com";
    # Keep the established Reality identity intact while introducing a
    # separately selectable Vision path for long-lived transfers.
    realityVisionEnable = true;
  };
}
