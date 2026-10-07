# ---
# Module: Target Gaming Switchboard
# Description: Unified entry point for game port forwarding and related ingress
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./forwarding.nix
  ];
}
