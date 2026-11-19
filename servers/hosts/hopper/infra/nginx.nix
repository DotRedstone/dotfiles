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
    # ⚠️ 2026-11-19：nixpkgs 默认 client_max_body_size = 10m，长会话（上下文十几 MB）
    # 的请求会被 nginx 直接 413 打回，根本到不了应用层。放到 64m。
    clientMaxBodySize = "64m";
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
