# ---
# Module: Dolphin Packages
# Description: Wrapped Dolphin binary with Breeze 6 style, thumbnailers and modern icon integration
# Scope: Home Manager
# ---

{ pkgs, customPapirus, ... }:

let
  dolphinWrapped = pkgs.symlinkJoin {
    name = "dolphin-wrapped";
    paths = [ pkgs.kdePackages.dolphin ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/dolphin \
        --prefix QT_PLUGIN_PATH : "${pkgs.kdePackages.qtsvg}/lib/qt-6/plugins:${pkgs.adwaita-qt6}/lib/qt-6/plugins:${pkgs.kdePackages.plasma-integration}/lib/qt-6/plugins:${pkgs.kdePackages.breeze}/lib/qt-6/plugins:${pkgs.kdePackages.konsole}/lib/qt-6/plugins:${pkgs.kdePackages.kdegraphics-thumbnailers}/lib/qt-6/plugins:${pkgs.kdePackages.ffmpegthumbs}/lib/qt-6/plugins:${pkgs.kdePackages.kimageformats}/lib/qt-6/plugins" \
        --prefix XDG_DATA_DIRS : "${customPapirus}/share:${pkgs.kdePackages.breeze-icons}/share:${pkgs.kdePackages.breeze}/share:${pkgs.kdePackages.plasma-integration}/share:${pkgs.kdePackages.konsole}/share" \
        --set QT_STYLE_OVERRIDE "adwaita-dark" \
        --set QT_QPA_PLATFORMTHEME "kde" \
        --run 'export KDE_COLOR_SCHEME_PATH="$HOME/.local/share/color-schemes/noctalia.colors"' \
        --run 'if [[ -f "$HOME/.config/dolphin/dolphin.qss" ]]; then set -- "-stylesheet" "$HOME/.config/dolphin/dolphin.qss" "$@"; fi'
    '';
  };
in
{
  home.packages = [
    dolphinWrapped
    pkgs.adwaita-qt6
    pkgs.kdePackages.breeze
    pkgs.kdePackages.breeze-icons
    pkgs.kdePackages.plasma-integration
    pkgs.kdePackages.konsole
    pkgs.kdePackages.kdegraphics-thumbnailers
    pkgs.kdePackages.ffmpegthumbs
    pkgs.kdePackages.kimageformats
    pkgs.kdePackages.qtsvg
    pkgs.kdePackages.kio-extras
  ];
}
