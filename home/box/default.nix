# ---
# Module: Box Home Entry
# Description: 云电脑 box 用户的 Home Manager 入口，仅组织模块
# Scope: Home Manager
# Notes:
# - 云电脑是平台维护的 Debian 镜像，重置后软件会被清空；本入口只管用户层，不放 root、内核或系统服务配置。
# - git、node、gh 等由平台镜像提供，不在此重复安装。
# ---
{ ... }:
{
  imports = [
    ./nix.nix
    ./network.nix
  ];

  home.username = "box";
  home.homeDirectory = "/home/box";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
