# ---
# Module: App - UU Remote Linux
# Description: 安装 UU 远程 Linux 被控端并以 niri 图形会话用户服务运行
# Scope: Home Manager
# ---
# Notes:
# - 登录凭据与设备身份保存在 ~/.config/uuremote/config.json（0600），不纳入仓库；
#   不要在机器间复制该文件，否则两台主机会互相踢出房间。
# - uinput 虚拟键鼠依赖 /dev/uinput 的 uaccess 规则，当前由 Steam 硬件规则提供；
#   移除 Steam 时需另行声明该 udev 规则，否则回退到 Wayland 原生虚拟键鼠。
# - 首次运行需在会话中执行 `uuremote-server login` 扫码；未登录时服务会弹出扫码窗口。
# - 刻意不启用自启动：没有 Install.WantedBy，单元是 static 状态，需要时手动
#   `systemctl --user start uuremote-native`，用完 stop 掉，避免常驻占用编码资源。

{ pkgs, ... }:
let
  uu-remote = pkgs.callPackage ./package.nix { };
in
{
  home.packages = [ uu-remote ];

  systemd.user.services.uuremote-native = {
    Unit = {
      Description = "UU Remote Linux host (unofficial)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${uu-remote}/bin/uuremote-server";
      Environment = [
        "RUST_LOG=info"
        # niri 多显示器切换；显示器布局变化后需重启服务。
        "UU_WAYLAND_MULTISCREEN=1"
      ];
      Restart = "always";
      RestartSec = 5;
    };
  };
}
