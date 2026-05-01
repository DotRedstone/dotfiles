# ---
# Module: Desktop - Environment
# Description: Global environment variables for theming, cursors, and locale
# Scope: System
# ---

{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.bibata-cursors ];

  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    LANG = "zh_CN.UTF-8";
    LANGUAGE = "zh_CN:zh";
  };
}
