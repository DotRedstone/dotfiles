# ---
# Module: GCP Free EasyTier Mesh
# Description: Lightweight EasyTier virtual LAN node without local listener
# Scope: Host
# ---

{ ... }: {
  dot.services.easytier = {
    enable = true;
    ipv4 = "10.8.0.4";
    hostname = "gcp-free";
    peers = [
      "tcp://47.110.239.66:11010"
      "udp://47.110.239.66:11010"
    ];
    noListener = true;
  };
}
