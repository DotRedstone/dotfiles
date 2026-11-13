# ---
# Module: App - KDE Connect
# Description: KDE Connect service and indicator for cross-device integration
# Scope: Home Manager
# ---
# Notes:
# - KDE 自带的 autostart 桌面文件会再生成一份 kdeconnectd 服务，与 Home Manager
#   的 kdeconnect.service 争抢守护进程；且 autostart 服务不随 home-manager
#   switch 重启，升级后会停留在旧版本导致指示器/插件通信异常。这里用用户级
#   autostart 文件（Hidden=true）屏蔽它，让 Home Manager 独占守护进程。

{ ... }: {
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  # 屏蔽 KDE autostart 生成的重复守护进程，避免升级后版本不一致。
  xdg.configFile."autostart/org.kde.kdeconnect.daemon.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
}
