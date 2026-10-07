# ---
# Module: Conduit Proxy Switchboard
# Description: Unified entry point for Conduit proxy node and subscription publishing
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./xray.nix
    ./subscriptions.nix
  ];
}
