# ---
# Module: Proxy Probe Ingress
# Description: 在现有 Nginx 443 入口为回环探测服务提供独立 HTTPS 名称
# Scope: System
# Notes:
# - DNS-01 可先于入口单独启用；证书签发与 HTTPS 入口必须分别验收。
# - 后端 TLS 使用同一证书并校验名称；不增加公网端口或改动现有 CDN 虚拟主机。
# ---

{ config, lib, pkgs, ... }:

let
  cfg = config.dot.services.proxyProbeIngress;
  probe = config.dot.services.proxyPreferredProbe;
  optimizerBody = pkgs.writeText "cf-optimizer-probe.txt"
    (lib.concatStrings (lib.replicate 256 "0123456789abcdef"));
  acmeCert = config.security.acme.certs.${cfg.serverName};
  certFile = if probe.tlsCertificateFile != null then probe.tlsCertificateFile
    else config.sops.secrets."proxy/probe_tls_cert".path;
  keyFile = if probe.tlsKeyFile != null then probe.tlsKeyFile
    else config.sops.secrets."proxy/probe_tls_key".path;
in
{
  options.dot.services.proxyProbeIngress = {
    enable = lib.mkEnableOption "the dedicated HTTPS ingress for the preferred probe";
    serverName = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Dedicated, Cloudflare-proxied probe hostname with a matching certificate.";
    };
    optimizerMarker = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Fixed origin marker for the public cf-optimizer probe; empty disables it.";
    };
    acme = {
      enable = lib.mkEnableOption "DNS-01 certificate preparation before exposing the probe ingress";
      contactEmail = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "ACME account contact supplied by the deployment host.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.acme.enable {
      assertions = [
        { assertion = builtins.match "[a-z0-9-]+(\\.[a-z0-9-]+)+" cfg.serverName != null;
          message = "probe ACME needs a DNS hostname"; }
        { assertion = cfg.acme.contactEmail != "";
          message = "probe ACME needs a contact email"; }
        { assertion = config.security.acme.acceptTerms;
          message = "probe ACME terms must be accepted explicitly"; }
      ];

      sops.secrets."proxy/probe_acme_dns_token" = {
        owner = "root";
        mode = "0400";
        restartUnits = [ "acme-order-renew-${cfg.serverName}.service" ];
      };

      security.acme = {
        certs.${cfg.serverName} = {
          email = cfg.acme.contactEmail;
          dnsProvider = "cloudflare";
          group = config.services.nginx.group;
          credentialFiles.CF_DNS_API_TOKEN_FILE =
            config.sops.secrets."proxy/probe_acme_dns_token".path;
          reloadServices = lib.optionals cfg.enable [
            "nginx.service"
            "proxy-preferred-probe.service"
          ];
        };
      };

      dot.services.proxyPreferredProbe = {
        tlsCertificateFile = "${acmeCert.directory}/fullchain.pem";
        tlsKeyFile = "${acmeCert.directory}/key.pem";
      };
    })

    (lib.mkIf cfg.enable {
      assertions = [
        { assertion = builtins.match "[a-z0-9-]+(\\.[a-z0-9-]+)+" cfg.serverName != null;
          message = "probe ingress requires a DNS hostname"; }
        { assertion = probe.listenHost == "127.0.0.1";
          message = "probe ingress requires the IPv4 loopback listener"; }
        { assertion = config.dot.services.xrayCdnWebSocket.enable;
          message = "probe ingress reuses the existing CDN Nginx listener"; }
        { assertion = cfg.serverName != config.dot.services.xrayCdnWebSocket.serverName;
          message = "probe ingress must not replace the existing CDN virtual host"; }
        { assertion = cfg.optimizerMarker == "" || builtins.match "[a-z0-9-]+" cfg.optimizerMarker != null;
          message = "cf-optimizer origin marker must contain only lowercase letters, digits and hyphens"; }
      ];

      dot.services.proxyPreferredProbe.enable = true;

      systemd.services.proxy-preferred-probe = lib.mkIf cfg.acme.enable {
        requires = [ "acme-order-renew-${cfg.serverName}.service" ];
        after = [ "acme-order-renew-${cfg.serverName}.service" ];
      };

      services.nginx.virtualHosts.${cfg.serverName} = {
        addSSL = true;
        sslCertificate = certFile;
        sslCertificateKey = keyFile;
        locations."/".extraConfig = "return 404;";
        locations."=/probe" = {
          proxyPass = "https://127.0.0.1:${toString probe.listenPort}";
          extraConfig = ''
            client_max_body_size 2k;
            proxy_cache off;
            proxy_ssl_server_name on;
            proxy_ssl_name ${cfg.serverName};
            proxy_ssl_verify on;
            proxy_ssl_verify_depth 2;
            proxy_ssl_trusted_certificate ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt;
          '';
        };
        locations."=/probe/uncached" = lib.mkIf (cfg.optimizerMarker != "") {
          extraConfig = ''
            # 仅接受 cf-optimizer 的单个随机 nonce，避免参数歧义和缓存复用。
            if ($request_method != GET) { return 405; }
            if ($args !~ "^nonce=[0-9a-f]{32}$") { return 400; }
            default_type text/plain;
            gzip off;
            max_ranges 0;
            add_header Cache-Control "no-store, max-age=0" always;
            add_header X-CF-Optimizer-Origin "${cfg.optimizerMarker}" always;
            add_header X-CF-Optimizer-Nonce $arg_nonce always;
            alias ${optimizerBody};
          '';
        };
      };
    })
  ];
}
