# ---
# Module: Hopper Nginx Base
# Description: Global Nginx engine settings, compression defaults, and firewall rules
# Scope: Host
# ---

{ ... }: {
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
