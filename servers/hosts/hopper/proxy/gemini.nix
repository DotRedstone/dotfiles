# ---
# Module: Hopper Gemini Reverse Proxy
# Description: Reverse proxy endpoint for Google Generative AI API (Gemini)
# Scope: Host
# ---

{ ... }: {
  services.nginx.virtualHosts."gemini.bdot.in" = {
    serverAliases = [ "gemini-origin.bdot.in" ];
    locations."/" = {
      proxyPass = "https://generativelanguage.googleapis.com/";
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_set_header Host generativelanguage.googleapis.com;
        proxy_ssl_server_name on;
        proxy_ssl_protocols TLSv1.2 TLSv1.3;
        proxy_buffering off;
        proxy_read_timeout 180s;
        proxy_send_timeout 180s;
      '';
    };
  };
}
