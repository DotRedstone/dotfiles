# ---
# Module: WeChat X11 Clipboard Bridge
# Description: 用 xwayclip 在微信的 XWayland 剪贴板与 Wayland 会话剪贴板之间双向同步
# Scope: Home Manager
# Notes:
# - 微信 4.x 的 launcher 硬编码 QT_QPA_PLATFORM=xcb，且闭包内没有 qtwayland 平台插件，
#   无法改为原生 Wayland，因此只能靠外部桥接。
# - xwayclip 通过 XFixes 与 ext/wlr-data-control 做全量快照同步，并用内容指纹抑制
#   双协议回声，替代了此前基于 1 秒轮询的自研实现。
# - 桥接范围是整会话剪贴板，不局限微信窗口；这是 xwayclip 的既有权衡。
# ---

{ pkgs, inputs, ... }:

let
  xwayclip = inputs.xwayclip.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  home.packages = [ xwayclip ];

  systemd.user.services.wechat-x11-clipboard-bridge = {
    Unit = {
      Description = "Bidirectional X11/Wayland clipboard sync (xwayclip)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${xwayclip}/bin/xwayclip";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
