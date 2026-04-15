# ---
# Module: WeChat
# Description: Official WeChat for Linux client
# ---

{ pkgs, ... }: {
  home.packages = [
    pkgs.wechat
  ];
}
