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
      "cdn"
      "guest"
    ];
    entryExpectedAddresses = {
      cdn = [ "sg-cdn.bdot.in" ];
      guest = [
        "107.174.1.97"
        "140.245.62.36"
        "la-cdn.bdot.in"
        "sg-cdn.bdot.in"
      ];
    };
  };

  dot.services.xrayDynamicSubscriptions = {
    enable = true;
    hostName = "sg-node.540123.xyz";
    entries.zjj = {
      accountName = "zjj";
      publicAddress = "140.245.62.36";
      realityPort = 20002;
      realityServerName = "www.nvidia.com";
      cdnHost = "sg-cdn.bdot.in";
      cdnPort = 443;
      poolLabel = "SG";
      preferredPoolUrlSecret = "xray/preferred_sg_url";
    };
  };
}
