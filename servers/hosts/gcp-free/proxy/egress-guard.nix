# ---
# Module: GCP Free Egress Guard
# Description: Egress traffic circuit breaker guarding against Google Cloud free tier overages
# Scope: Host
# ---

{ ... }: {
  dot.services.gcpEgressGuard = {
    enable = true;
    interface = "eth0";
    limitBytes = 180000000000;
    guardedUnits = [
      "xray.service"
      "easytier.service"
    ];
  };
}
