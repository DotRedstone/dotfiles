# ---
# Module: Target Preferred Probe TLS
# Description: 为 Target 优选探测入口申请 DNS-01 证书并转发独立 HTTPS 端口
# Scope: Host
# Notes:
# - 默认关闭；启用前需核对腾讯云安全组、域名解析、SOPS 运行时和证书申请账户。
# - Nginx 仅透传 TLS，探测请求仍由回环服务校验 HMAC。
# ---

{ config, lib, ... }:

let
  cfg = config.dot.services.targetProbeTls;
  probe = config.dot.services.proxyPreferredProbe;
  certificateDir = config.security.acme.certs.${cfg.domain}.directory;
in
{
  options.dot.services.targetProbeTls = {
    enable = lib.mkEnableOption "Target preferred probe DNS-01 and TLS ingress";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "probe-v2-canary.dotdot.ggff.net";
      description = "Dedicated public name for the isolated probe.";
    };
    contactEmail = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "ACME account contact email, supplied before enabling.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = cfg.contactEmail != ""; message = "Target probe ACME contact email is required"; }
      { assertion = config.security.acme.acceptTerms;
        message = "Target probe ACME terms must be accepted explicitly"; }
      { assertion = probe.listenHost == "127.0.0.1";
        message = "Target probe TLS ingress requires the loopback IPv4 listener"; }
    ];

    sops.secrets."proxy/probe_acme_dns_token" = {
      owner = "root";
      mode = "0400";
      restartUnits = [ "acme-order-renew-${cfg.domain}.service" ];
    };

    security.acme = {
      defaults.email = cfg.contactEmail;
      certs.${cfg.domain} = {
        dnsProvider = "cloudflare";
        credentialFiles.CF_DNS_API_TOKEN_FILE =
          config.sops.secrets."proxy/probe_acme_dns_token".path;
        reloadServices = [ "proxy-preferred-probe.service" ];
      };
    };

    dot.services.proxyPreferredProbe = {
      enable = true;
      tlsCertificateFile = "${certificateDir}/fullchain.pem";
      tlsKeyFile = "${certificateDir}/key.pem";
    };

    systemd.services.proxy-preferred-probe = {
      requires = [ "acme-order-renew-${cfg.domain}.service" ];
      after = [ "acme-order-renew-${cfg.domain}.service" ];
    };

    services.nginx = {
      enable = true;
      streamConfig = ''
        server {
          listen 443;
          proxy_connect_timeout 3s;
          proxy_timeout 30s;
          proxy_pass 127.0.0.1:${toString probe.listenPort};
        }
      '';
    };
    networking.firewall.allowedTCPPorts = [ 443 ];
  };
}
