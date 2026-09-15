# ---
# Module: Conduit Networking
# Description: Static RackNerd IPv4 routing and resolver configuration
# Scope: Host
# Notes:
# - RackNerd does not provide DHCP on this VM; changing these values can sever SSH.
# ---

{ lib, ... }: {
  boot.kernelParams = [
    "net.ifnames=0"
    "biosdevname=0"
  ];

  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
  ];

  systemd.network.networks."10-wan" = lib.mkForce {
    matchConfig.Name = "eth0";
    address = [ "107.174.1.97/26" ];
    routes = [
      {
        Gateway = "107.174.1.65";
        GatewayOnLink = true;
      }
    ];
    networkConfig = {
      DHCP = "no";
      IPv6AcceptRA = false;
    };
    linkConfig.RequiredForOnline = "routable";
  };
}
