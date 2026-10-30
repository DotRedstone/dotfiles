# ---
# Module: Hopper Private Deployment Example
# Description: Supply synthetic proof identity and probe certificate name
# Scope: Host
# ---

{ lib, ... }: {
  dot.services.proxyOriginProof.originId = lib.mkForce "sample-origin-b";
  dot.services.proxyProbeIngress.serverName = lib.mkForce "probe-b.example.test";
}
