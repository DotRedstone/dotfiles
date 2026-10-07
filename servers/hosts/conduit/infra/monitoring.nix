# ---
# Module: Conduit Monitoring Agent
# Description: Komari host telemetry and monitoring agent
# Scope: Host
# ---

{ ... }: {
  dot.services.komariAgent.enable = true;
}
