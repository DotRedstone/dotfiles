# ---
# Module: Server Services Switchboard
# Description: Unified entry point for independently reusable server service modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./easytier.nix
    ./gcp-egress-guard.nix
    ./komari-agent.nix
    ./mongodb.nix
    ./mysql.nix
    ./navidrome.nix
    ./nix-cache-relay.nix
    ./openlist.nix
    ./postgresql.nix
    ./redis.nix
    ./restic-backup.nix
    ./restic-client.nix
    ./restic-receiver.nix
    ./rustfs.nix
    ./xray-gateway.nix
    ./xray-node.nix
    ./xray-subscriptions.nix
  ];
}
