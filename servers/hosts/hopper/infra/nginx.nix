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

    # NixOS 默认为 10m。长上下文会话的请求体可达十几 MB，走默认值的 vhost
    # 会被 nginx 直接以 413 拒绝，且不会到达上游应用。
    clientMaxBodySize = "64m";
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
