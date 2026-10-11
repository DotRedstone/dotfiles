# ---
# Module: Server Services Switchboard
# Description: Unified entry point for independently reusable server service modules
# Scope: System
# ---

{ proxyStack ? null, ... }: {
  imports = [
    ./easytier.nix
    ./gcp-egress-guard.nix
    ./hysteria2-node.nix
    ./komari-agent.nix
    ./mongodb.nix
    ./mysql.nix
    ./navidrome.nix
    ./nix-cache-relay.nix
    ./openlist.nix
    ./postgresql.nix
    ./proxy-delivery-publisher.nix
    ./proxy-origin-proof.nix
    ./proxy-preferred-probe.nix
    ./proxy-accounts.nix
    ./redis.nix
    ./restic-backup.nix
    ./restic-client.nix
    ./restic-receiver.nix
    ./rustfs.nix
    ./xray-gateway.nix
    ./xray-cdn-websocket.nix
    ./xray-subscriptions.nix
  ] ++ [ (if proxyStack == null then ./xray-node.nix else proxyStack.nixosModules.xrayNode) ];
}
