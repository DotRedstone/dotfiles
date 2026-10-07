# ---
# Module: GCP Free Xray Gateway
# Description: Minimal Xray egress proxy gateway for Google Cloud node
# Scope: Host
# ---

{ ... }: {
  dot.services.xrayGateway.enable = true;
}
