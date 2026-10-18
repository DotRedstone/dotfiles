# ---
# Module: Target Private Deployment Example
# Description: Supply a synthetic domain for the disabled TLS probe candidate
# Scope: Host
# ---

{ lib, ... }: {
  dot.services.targetProbeTls.domain = lib.mkForce "probe-target.example.test";
}
