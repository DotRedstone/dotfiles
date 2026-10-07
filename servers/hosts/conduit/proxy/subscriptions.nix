# ---
# Module: Conduit Xray Subscriptions
# Description: Subscription endpoint publisher for Conduit proxy endpoints
# Scope: Host
# ---

{ ... }: {
  dot.services.xraySubscriptions = {
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
}
