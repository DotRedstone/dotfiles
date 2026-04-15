# ---
# Module: WezTerm
# Description: GPU-accelerated terminal emulator with Lua configuration
# ---

{ config, ... }: {
  programs.wezterm.enable = true;

  # [Configuration Link]
  # Symlinking for live-reloading without home-manager activation
  xdg.configFile."wezterm/wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/home/dot/wezterm/config.lua";
}
