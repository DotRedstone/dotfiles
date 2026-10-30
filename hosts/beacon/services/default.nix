# ---
# Module: Beacon Services Entry
# Description: Switchboard importing and activating application services for beacon
# Scope: Host
# ---

{ ... }:

{
  imports = [
    ./minecraft.nix
    ./ai.nix
  ];

  # [Enabled Services]
  services.minecraft-server.enable = true;
  services.beacon-ai.enable = true;
}
