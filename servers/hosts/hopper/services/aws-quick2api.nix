# ---
# Module: Hopper AWS Quick2API
# Description: Run aws-quick2api OpenAI/Anthropic gateway and expose aq.bdot.in via Nginx
# Scope: Host
# Notes:
# - Built application files and runtime credentials live under /var/lib/aws-quick2api.
# ---

{ pkgs, ... }:
let
  stateDir = "/var/lib/aws-quick2api";
in
{
  systemd.services.aws-quick2api = {
    description = "aws-quick2api OpenAI & Anthropic Gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "dot";
      Group = "users";
      WorkingDirectory = "${stateDir}/app";
      EnvironmentFile = "${stateDir}/.env";
      ExecStart = "${pkgs.nodejs}/bin/node ${stateDir}/app/dist/src/server.js";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  services.nginx.virtualHosts."aq.bdot.in" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:3456";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
      '';
    };
  };
}
