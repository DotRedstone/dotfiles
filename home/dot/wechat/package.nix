# ---
# Module: WeChat - Base Package
# Description: Low-level derivation for WeChat UOS and its bridge
# Scope: Home Manager
# ---

{ pkgs }:
let
  wechatSource = {
    url = "https://dldir1.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb";
    hash = "sha256-t9D41T6fZIvCx3pglqBBANAI8tnw05iKKkhZtZkqygo=";
  };

  wechatDeb = pkgs.fetchurl wechatSource;

  # 4.1.13.23 moved its payload from /opt/apps/com.tencent.wechat to
  # /opt/wechat. Keep the current Nixpkgs FHS wrapper working while it still
  # expects the previous path; the compatibility links do not alter WeChat.
  wechatCompatDeb = pkgs.runCommand "wechat-uos-4.1.13.23-compat.deb" {
    nativeBuildInputs = [ pkgs.dpkg ];
  } ''
    dpkg-deb -R ${wechatDeb} package
    mkdir -p package/opt/apps/com.tencent.wechat/entries/applications
    ln -s ../../wechat package/opt/apps/com.tencent.wechat/files
    ln -s ../../../../usr/share/icons package/opt/apps/com.tencent.wechat/entries/icons
    cp package/usr/share/applications/wechat.desktop \
      package/opt/apps/com.tencent.wechat/entries/applications/com.tencent.wechat.desktop
    dpkg-deb -b package "$out"
  '';

  wechat-uos = pkgs.callPackage (pkgs.path + "/pkgs/by-name/we/wechat-uos/package.nix") {
    # nixpkgs still pins 4.1.1.7. Keep the official Universal package on the
    # latest verified upstream release until nixpkgs catches up.
    fetchurl = _: wechatCompatDeb;
    writeShellScript = name: text:
      pkgs.writeShellScript name (
        if name == "wechat-uos-launcher" then
          builtins.replaceStrings
            [ "export QT_AUTO_SCREEN_SCALE_FACTOR=1" ]
            [ ''
              export QT_AUTO_SCREEN_SCALE_FACTOR=''${QT_AUTO_SCREEN_SCALE_FACTOR:-0}
              export QT_ENABLE_HIGHDPI_SCALING=''${QT_ENABLE_HIGHDPI_SCALING:-0}
              export QT_SCALE_FACTOR=''${QT_SCALE_FACTOR:-1}
            '' ]
            text
        else
          text
      );
  };

  notifyBridge = pkgs.stdenv.mkDerivation {
    pname = "wechat-notify-bridge";
    version = "0.1.0";

    src = ./bridge-rs;

    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.rustc
    ];

    buildPhase = ''
      runHook preBuild
      rustc --edition=2021 -O src/main.rs -o wechat-notify-bridge
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 wechat-notify-bridge $out/bin/wechat-notify-bridge
      wrapProgram $out/bin/wechat-notify-bridge \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.libnotify
            pkgs.sqlcipher
          ]
        }
      runHook postInstall
    '';
  };
in
{
  inherit
    notifyBridge
    wechat-uos
    ;
}
