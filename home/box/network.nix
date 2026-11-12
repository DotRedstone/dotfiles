# ---
# Module: Box Network Tools
# Description: 安装云电脑上的代理内核 mihomo（仅安装，不含节点与启动配置）
# Scope: Home Manager
# Notes:
# - 节点、订阅和密钥不得写入本仓库；后续经 SOPS 引用。
# ---
{ pkgs, ... }:
{
  home.packages = [ pkgs.mihomo ];
}
