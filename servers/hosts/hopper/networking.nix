# ---
# Module: Hopper Networking
# Description: Oracle VCN DHCP, jumbo-frame, and serial-safe network configuration
# Scope: Host
# Notes:
# - Oracle provides the private address, default route, and metadata DNS through DHCPv4.
# - The public address is NATed by Oracle and must not be configured inside the guest.
# ---

{ lib, ... }: {
  boot.kernelParams = [
    "net.ifnames=0"
    "biosdevname=0"
    "console=tty1"
    "console=ttyAMA0,115200n8"
  ];

  systemd.network.networks."10-wan" = lib.mkForce {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    dhcpV4Config = {
      UseDNS = true;
      UseRoutes = true;
    };
    linkConfig = {
      MTUBytes = 9000;
      RequiredForOnline = "routable";
    };
  };
}
