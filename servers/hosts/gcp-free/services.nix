# ---
# Module: GCP Free Services
# Description: Host-specific service wiring for mesh, proxy, monitoring, and egress safety
# Scope: Host
# ---

{ ... }: {
  dot.services = {
    easytier = {
      enable = true;
      ipv4 = "10.8.0.4";
      hostname = "gcp-free";
      peers = [
        "tcp://47.110.239.66:11010"
        "udp://47.110.239.66:11010"
      ];
      noListener = true;
    };

    komariAgent.enable = true;
    xrayGateway.enable = true;

    gcpEgressGuard = {
      enable = true;
      interface = "eth0";
      limitBytes = 180000000000;
      guardedUnits = [
        "xray.service"
        "easytier.service"
      ];
    };
  };
}
