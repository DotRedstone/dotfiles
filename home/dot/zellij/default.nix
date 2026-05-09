# ---
# Module: Zellij
# Description: Terminal workspace with Noctalia dynamic theme integration
# Scope: Home Manager
# ---

{ config, lib, ... }:
{
  programs.zellij.enable = true;

  # [Dynamic Configuration Link]
  # Symlink to noctalia-generated cache for real-time theme updates
  xdg.configFile."zellij/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/zellij.kdl";

  xdg.configFile."zellij/layouts" = {
    force = true;
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/home/dot/zellij/layouts";
  };

  home.activation.replaceZellijLayoutsDir = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    target="${config.xdg.configHome}/zellij/layouts"
    if [ -d "$target" ] && [ ! -L "$target" ]; then
      if find "$target" -mindepth 1 -maxdepth 1 ! -type l | grep -q .; then
        echo "Refusing to replace $target because it contains non-symlink files." >&2
        exit 1
      fi
      rm -rf "$target"
    fi
  '';
}
