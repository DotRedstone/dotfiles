# ---
# Module: Ghostty
# Description: GPU 加速、原生 Wayland 的终端模拟器，用于评估替代 WezTerm
# Scope: Home Manager
# ---

{ config, pkgs, ... }:

let
  dotfilesGhostty = "${config.home.homeDirectory}/.dotfiles/home/dot/ghostty";
in {
  home.packages = [ pkgs.ghostty ];

  # [Configuration Link]
  # 指向仓库内的 config，便于试用期直接改参数而不必每次 switch
  xdg.configFile."ghostty/config" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesGhostty}/config";
    force = true;
  };
}
