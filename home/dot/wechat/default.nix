# ---
# Module: WeChat
# Description: Official WeChat for Linux client plus Noctalia notification bridge
# ---

{ pkgs, ... }:
let
  wechat = pkgs.callPackage ./package.nix { };
in
{
  home.packages = [
    wechat.wechat-uos
    wechat.notifyBridge
    pkgs.libnotify
  ];

  xdg.desktopEntries."com.tencent.wechat" = {
    name = "微信 UOS";
    genericName = "WeChat UOS";
    comment = "微信桌面版 UOS";
    exec = "wechat-uos -- %U";
    icon = "com.tencent.wechat";
    terminal = false;
    categories = [ "Chat" ];
    startupNotify = true;
    settings = {
      StartupWMClass = "wechat";
    };
  };

  systemd.user.services.wechat-notify-bridge = {
    Unit = {
      Description = "Bridge WeChat activity into desktop notifications";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${wechat.notifyBridge}/bin/wechat-notify-bridge";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
