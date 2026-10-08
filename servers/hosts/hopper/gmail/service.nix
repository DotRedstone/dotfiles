# ---
# Module: Hopper Gmail Service
# Description: Gmail archiver daemon configuration and Nginx reverse proxy
# Scope: Host
# ---

{ config, ... }: {
  services.gmail-archiver = {
    enable = true;
    imapUser = "dotredstone0123@gmail.com";
    imapServer = "imap.gmail.com:993";
    environmentFile = config.sops.templates."gmail-archiver.env".path;
    dataDir = "/var/lib/gmail-archiver";
    httpPort = 8080;
  };

  systemd.services.gmail-archiver = {
    preStart = ''
      mkdir -p /var/lib/gmail-archiver/rosters
      mkdir -p /var/lib/gmail-archiver/rules
      mkdir -p /var/lib/gmail-archiver/attachments
    '';
  };

  services.nginx.virtualHosts."gmail.bdot.in" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
