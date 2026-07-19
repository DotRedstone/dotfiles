# ---
# Module: Office
# Description: Office suites and document tools
# Scope: Home Manager
# ---

{ config, pkgs, ... }:

let
  qt5PluginPath = "${config.home.profileDirectory}/${pkgs.qt5.qtbase.qtPluginPrefix}";
  qt5ctPluginPath = "${pkgs.libsForQt5.qt5ct}/${pkgs.qt5.qtbase.qtPluginPrefix}";

  wemeetDark = pkgs.wemeet.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      for launcher in "$out/bin/wemeet" "$out/bin/wemeet-xwayland"; do
        substituteInPlace "$launcher" \
          --replace-fail "export QT_STYLE_OVERRIDE='fusion'" \
          "export QT_STYLE_OVERRIDE='Fusion'; export QT_QPA_PLATFORMTHEME='qt5ct'; export QT_PLUGIN_PATH='${qt5PluginPath}'"
      done
    '';
  });

  wpsofficeDark = pkgs.wpsoffice-cn.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postFixup = (old.postFixup or "") + ''
      wpsQtPlugins="$out/opt/kingsoft/wps-office/office6/qt/plugins"
      ln -sf "${qt5ctPluginPath}/platformthemes/libqt5ct.so" \
        "$wpsQtPlugins/platformthemes/libqt5ct.so"
      mkdir -p "$wpsQtPlugins/styles"
      ln -sf "${qt5ctPluginPath}/styles/libqt5ct-style.so" \
        "$wpsQtPlugins/styles/libqt5ct-style.so"

      for launcher in wps wpp et wpspdf; do
        wrapProgram "$out/bin/$launcher" \
          --set QT_QPA_PLATFORMTHEME qt5ct \
          --set QT_STYLE_OVERRIDE Fusion \
          --prefix QT_PLUGIN_PATH : "${qt5PluginPath}"
      done
    '';
  });
in
{
  home.packages = with pkgs; [
    wpsofficeDark
    wemeetDark
  ];
}
