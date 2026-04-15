# ---
# Module: Niri Links
# Description: Out-of-store symlinks for direct KDL editing
# ---

{ config, ... }: {
  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/home/dot/niri/config.kdl";
}
