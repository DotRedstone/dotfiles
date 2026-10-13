# ---
# Module: Proxy Probe Ingress
# Description: 在现有 Nginx 443 入口为回环探测服务提供独立 HTTPS 名称
# Scope: System
# Notes:
# - 默认关闭；启用前需为独立名称准备可信证书、DNS 和两地各自的探测环境密文。
# - 后端 TLS 使用同一证书并校验名称；不增加公网端口或改动现有 CDN 虚拟主机。
# ---

{ config, lib, pkgs, ... }:

let
  cfg = config.dot.services.proxyProbeIngress;
  probe = config.dot.services.proxyPreferredProbe;
in
{
  options.dot.services.proxyProbeIngress = {
    enable = lib.mkEnableOption "the dedicated HTTPS ingress for the preferred probe";
    serverName = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Dedicated, Cloudflare-proxied probe hostname with a matching certificate.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = builtins.match "[a-z0-9-]+(\\.[a-z0-9-]+)+" cfg.serverName != null;
        message = "probe ingress requires a DNS hostname"; }
      { assertion = probe.listenHost == "127.0.0.1";
        message = "probe ingress requires the IPv4 loopback listener"; }
      { assertion = probe.tlsCertificateFile == null && probe.tlsKeyFile == null;
        message = "probe ingress and loopback probe must share the SOPS TLS certificate"; }
      { assertion = config.dot.services.xrayCdnWebSocket.enable;
        message = "probe ingress reuses the existing CDN Nginx listener"; }
      { assertion = cfg.serverName != config.dot.services.xrayCdnWebSocket.serverName;
        message = "probe ingress must not replace the existing CDN virtual host"; }
    ];

    dot.services.proxyPreferredProbe.enable = true;

    services.nginx.virtualHosts.${cfg.serverName} = {
      addSSL = true;
      sslCertificate = config.sops.secrets."proxy/probe_tls_cert".path;
      sslCertificateKey = config.sops.secrets."proxy/probe_tls_key".path;
      locations."/".extraConfig = "return 404;";
      locations."=/probe" = {
        proxyPass = "https://127.0.0.1:${toString probe.listenPort}";
        extraConfig = ''
          client_max_body_size 2k;
          proxy_cache off;
          proxy_ssl_server_name on;
          proxy_ssl_name ${cfg.serverName};
          proxy_ssl_verify on;
          proxy_ssl_trusted_certificate ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt;
        '';
      };
    };
  };
}
