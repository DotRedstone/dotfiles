# ---
# Module: WezTerm
# Description: GPU-accelerated terminal emulator with Lua configuration
# Scope: Home Manager
# ---

{ config, ... }:

let
  dotfilesWezterm = "${config.home.homeDirectory}/.dotfiles/home/dot/wezterm";
in {
  programs.wezterm.enable = true;

  # [Configuration Link]
  # Symlinking for live-reloading without home-manager activation
  # 'force = true' ensures we overwrite any existing regular files at these paths
  xdg.configFile."wezterm/wezterm.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/config.lua";
    force = true;
  };

  xdg.configFile."wezterm/modules/visuals.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/visuals.lua";
    force = true;
  };

  xdg.configFile."wezterm/modules/ui.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/ui.lua";
    force = true;
  };

  xdg.configFile."wezterm/modules/performance.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/performance.lua";
    force = true;
  };

  xdg.configFile."wezterm/modules/theme.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/theme.lua";
    force = true;
  };

  xdg.configFile."wezterm/modules/ssh.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/ssh.lua";
    force = true;
  };

  xdg.configFile."wezterm/modules/keybindings.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWezterm}/modules/keybindings.lua";
    force = true;
  };
}
