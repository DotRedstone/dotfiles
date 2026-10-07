# ---
# Module: Hopper Nix Cache Relay
# Description: Local binary cache relay serving cache hits to workstation and nodes
# Scope: Host
# ---

{ ... }: {
  dot.services.nixCacheRelay = {
    enable = true;
    # The fixed Oracle public IP avoids depending on a DNS record or Cloudflare.
    serverAliases = [ "140.245.62.36" ];
  };
}
