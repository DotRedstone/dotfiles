# ---
# Module: Hopper CDN WebSocket Edge
# Description: Cloudflare-fronted VLESS WebSocket endpoint for the Singapore edge.
# Scope: Host
# ---

{ ... }: {
  dot.services.xrayCdnWebSocket = {
    enable = true;
    serverName = "sg-cdn.bdot.in";
  };
}
