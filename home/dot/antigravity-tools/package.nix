# ---
# Module: Antigravity Tools Package
# Description: Antigravity 多账号管理/切换客户端，从上游 AppImage 打包
# Scope: Home Manager
# Notes:
# - 上游只发布 .deb/.rpm/.AppImage，没有 Nix 包，这里按仓库既有的
#   appimageTools.wrapType2 方式封装（同 grok-bot / workbuddy）。
# - 版本升级时要同时替换 version 与 hash，并从 release 资源名确认 amd64.AppImage 仍在。
# ---

{ pkgs }:
let
  pname = "antigravity-tools";
  version = "5.0.4";

  src = pkgs.fetchurl {
    url = "https://github.com/lbjlaq/Antigravity-Manager/releases/download/v${version}/Antigravity.Tools_${version}_amd64.AppImage";
    hash = "sha256-sKrngQ3T6j2OdQ8qxWHeJWZBsvb2ybNspWjMTr55fDk=";
  };

  extracted = pkgs.appimageTools.extract {
    inherit pname version src;
  };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  # AppImage 不自带这些库，缺了会报 libgpg-error.so.0 之类的加载失败。
  extraPkgs = pkgs: [
    pkgs.libgpg-error
  ];

  extraInstallCommands = ''
    install -m 444 -D "${extracted}/Antigravity Tools.desktop" \
      $out/share/applications/antigravity-tools.desktop
    install -m 444 -D "${extracted}/antigravity-tools.png" \
      $out/share/icons/hicolor/512x512/apps/antigravity-tools.png
  '';
}
