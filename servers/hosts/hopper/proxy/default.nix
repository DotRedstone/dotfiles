# ---
# Module: Hopper Proxy Switchboard
# Description: Unified entry point for Hopper egress proxies and subscription publishing
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./cdn-websocket.nix
    ./hysteria2.nix
    ./xray.nix
    ./subscriptions.nix
    ./gemini.nix
  ];
}
