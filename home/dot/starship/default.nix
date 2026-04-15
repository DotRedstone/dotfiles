# ---
# Module: Starship
# Description: Minimalist shell prompt with Noctalia dynamic theme integration
# ---

{ config, lib, ... }: {

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };

  # [Dynamic Theme Link]
  # Symlink to noctalia-generated cache for real-time color updates
  xdg.configFile."starship.toml" = {
    source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/starship.toml");
  };
}
