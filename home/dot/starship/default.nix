# ---
# Module: Starship
# Description: Minimalist shell prompt with Noctalia dynamic theme integration
# Scope: Home Manager
# ---

{ config, lib, ... }: {

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };

}
