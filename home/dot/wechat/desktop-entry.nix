# ---
# Module: WeChat Desktop Entry
# Description: XDG desktop entry for WeChat UOS
# Scope: Home Manager
# ---

{ ... }: {
  xdg.desktopEntries."com.tencent.wechat" = {
    name = "微信";
    genericName = "即时通讯";
    comment = "微信桌面版";
    exec = "wechat-uos -- %U";
    icon = "wechat";
    terminal = false;
    categories = [ "Chat" "Network" ];
    startupNotify = true;
    settings = {
      StartupWMClass = "wechat";
    };
  };
}
