# ---
# Module: Server Networking
# Description: DHCP networking and a deny-by-default host firewall for cloud servers
# Scope: System
# ---

{ ... }: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    dhcpcd.enable = false;

    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  systemd.network = {
    enable = true;
    networks."10-wan" = {
      matchConfig.Name = "en* eth*";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
