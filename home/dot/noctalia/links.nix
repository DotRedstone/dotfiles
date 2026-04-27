# ---
# Module: Noctalia Links
# Description: Symlink entire config directory to dotfiles for Git portability
# ---

{ config, ... }: {
  xdg.configFile."noctalia".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/home/dot/noctalia/config";
}
