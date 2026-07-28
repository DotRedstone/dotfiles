# ---
# Module: Network - ToDesk
# Description: ToDesk remote control service
# Scope: System
# ---

{ pkgs, ... }: {
  services.todesk.enable = true;
  environment.systemPackages = [ pkgs.todesk ];
}
