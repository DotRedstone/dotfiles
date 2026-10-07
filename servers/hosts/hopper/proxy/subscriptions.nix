# ---
# Module: Hopper Xray Subscriptions
# Description: Subscription endpoint publisher for Hopper egress proxy nodes
# Scope: Host
# ---

{ ... }: {
  dot.services.xraySubscriptions = {
    enable = true;
    hostName = "sg-node.540123.xyz";
    publicAddress = "140.245.62.36";
    entryNames = [
      "hysteria2"
      "websocket"
      "reality"
    ];
  };
}
