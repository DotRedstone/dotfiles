# ---
# Module: Fcitx5 Kimpanel Popup
# Description: Packages the Kimpanel D-Bus bridge and installs the DMS candidate popup plugin.
# Scope: Home Manager
# Notes:
# - 插件需在 DMS 中启用一次：dms ipc call plugins enable fcitxKimpanel
# - 插件停用或 DMS 退出后，Fcitx5 自动回退到 classicui。
# ---

{ pkgs, ... }:

let
  bridge = pkgs.writeShellScriptBin "fcitx5-kimpanel-bridge" ''
    unset PYTHONHOME PYTHONPATH
    export KIMPANEL_LIBSYSTEMD=${pkgs.systemd}/lib/libsystemd.so.0
    exec ${pkgs.python3}/bin/python3 -u ${./bridge.py} "$@"
  '';

  plugin = pkgs.runCommand "dms-plugin-fcitx-kimpanel" { } ''
    cp -r ${./plugin} $out
    chmod -R u+w $out
    substituteInPlace $out/KimpanelDaemon.qml \
      --replace-fail "@bridge@" "${bridge}/bin/fcitx5-kimpanel-bridge"
  '';
in
{
  home.packages = [ bridge ];

  home.file.".config/dms/plugins/fcitxKimpanel".source = plugin;
}
