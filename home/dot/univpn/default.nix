# ---
# Module: UniVPN Switchboard
# Description: Installs and registers UniVPN desktop application
# Scope: Home Manager
# ---

{ pkgs, config, ... }:
let
  univpn = pkgs.callPackage ./package.nix { };
in
{
  home.packages = [
    univpn
  ];

  # UniVPN 把连接配置（key.ini）写在 ~/UniVPN/config；用符号链接指向已持久化的
  # /var/lib/univpn/config（见 modules/system/persistence/system-paths.nix），
  # 避免 /home 重建后凭据丢失。~/UniVPN 本身整体持久化在 user-apps.nix。
  home.file."UniVPN/config".source =
    config.lib.file.mkOutOfStoreSymlink "/var/lib/univpn/config";
}
