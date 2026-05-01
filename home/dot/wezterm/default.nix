# ---
# Module: WezTerm
# Description: GPU-accelerated terminal emulator with Lua configuration
# ---

{ config, ... }:

let
  dotfilesWezterm = "${config.home.homeDirectory}/.dotfiles/home/dot/wezterm";
in {
  programs.wezterm.enable = true;

  # [Configuration Link]
  # Symlinking for live-reloading without home-manager activation
  xdg.configFile."wezterm/wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/config.lua";

  xdg.configFile."wezterm/modules/visuals.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/visuals.lua";

  xdg.configFile."wezterm/modules/ui.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/ui.lua";

  xdg.configFile."wezterm/modules/performance.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/performance.lua";

  xdg.configFile."wezterm/modules/theme.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/theme.lua";

  xdg.configFile."wezterm/modules/ssh.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/ssh.lua";

  xdg.configFile."wezterm/modules/keybindings.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/keybindings.lua";
}
