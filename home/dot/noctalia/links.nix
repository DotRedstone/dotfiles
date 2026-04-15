# ---
# Module: Noctalia Links
# Description: Symlinking Noctalia assets for live-editing
# ---

{ config, ... }: {
  # [Directory Symlink]
  # Bridges the local config folder to XDG_CONFIG_HOME
  xdg.configFile."noctalia".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/home/dot/noctalia/config";
}
