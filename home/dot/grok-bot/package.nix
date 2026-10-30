# ---
# Module: Grok Bot Package
# Description: Official Grok Bot desktop client wrapped for Linux
# Scope: Home Manager
# ---

{ pkgs }:
let
  pname = "grok-bot";
  version = "0.78.1";
  commitSha = "72e130b4e6be3fdc47b97e809b6b420908ce2dd8";

  src = pkgs.fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${commitSha}/linux/x64/Grok_Bot_${version}.AppImage";
    hash = "sha256-BQ11I8bvoEYmYROuLjsfPOlAlVSSwrlS/T5pi2DXP7g=";
  };

  extracted = pkgs.appimageTools.extract {
    inherit pname version src;
  };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${extracted}/grok-bot.desktop $out/share/applications/grok-bot.desktop
    cp -r ${extracted}/usr/share/icons $out/share/

    # 包装启动脚本以默认注入 Wayland 原生合成支持
    mv $out/bin/grok-bot $out/bin/.grok-bot-unwrapped
    cat > $out/bin/grok-bot << 'EOF'
#!/bin/sh
DIR="$(dirname "$(readlink -f "$0")")"
exec "$DIR/.grok-bot-unwrapped" --ozone-platform-hint=auto "$@"
EOF
    chmod +x $out/bin/grok-bot

    substituteInPlace $out/share/applications/grok-bot.desktop \
      --replace-fail 'AppRun --no-sandbox --' 'grok-bot'
  '';

  meta = with pkgs.lib; {
    description = "Official Grok Bot desktop client";
    homepage = "https://cursor.com";
    platforms = [ "x86_64-linux" ];
  };
}
