# ---
# Module: Target EasyTier Relay
# Description: Authenticated domestic EasyTier relay node with public listener
# Scope: Host
# ---

{ ... }: {
  dot.services.easytier = {
    enable = true;
    ipv4 = "10.8.0.3";
    hostname = "tencent-node";
    # Match the local router's authenticated EasyTier identity. The legacy
    # Aliyun relay accepts a different configuration shape, so it is not a
    # credential source for new nodes.
    useNetworkSecret = true;
    peers = [ "tcp://47.110.239.66:11010" ];
    noListener = false;
    listenPort = 11010;
  };
}
