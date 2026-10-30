# ---
# Module: Conduit Private Deployment Example
# Description: Supply synthetic proof identity and probe certificate name
# Scope: Host
# ---

{ lib, ... }: {
  dot.services.proxyOriginProof.originId = lib.mkForce "sample-origin-a";
  dot.services.proxyProbeIngress.serverName = lib.mkForce "probe-a.example.test";
}
