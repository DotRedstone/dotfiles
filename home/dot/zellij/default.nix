# ---
# Module: Zellij
# Description: Terminal workspace with Noctalia dynamic theme integration
# ---

{ config, lib, ... }:
{
  programs.zellij.enable = true;

  # [Dynamic Configuration Link]
  # Symlink to noctalia-generated cache for real-time theme updates
  xdg.configFile."zellij/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/zellij.kdl";

  xdg.configFile."zellij/layouts/vibe.kdl".source = ./layouts/vibe.kdl;
}
