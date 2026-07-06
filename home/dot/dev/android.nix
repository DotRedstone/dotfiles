# ---
# Module: Android Development
# Description: Android Studio IDE for Android application development
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  androidStudio = pkgs.android-studio;
  androidStudioLauncher = pkgs.writeShellScriptBin "android-studio" ''
    unset CODEX_CI
    unset GDK_BACKEND
    unset QT_PLUGIN_PATH
    unset QT_QPA_PLATFORM
    unset QT_QPA_PLATFORMTHEME
    unset QT_STYLE_OVERRIDE
    unset QT_WAYLAND_DISABLE_WINDOWDECORATION

    export _JAVA_AWT_WM_NONREPARENTING=1
    export JDK_JAVA_OPTIONS="''${JDK_JAVA_OPTIONS:-} -Dsun.java2d.xrender=false -Dide.browser.jcef.gpu.disable=true -Dide.ui.new.ui.custom.decorations.on.linux=false"

    exec ${androidStudio}/bin/android-studio "$@"
  '';

  androidStudioDesktop = pkgs.makeDesktopItem {
    name = "android-studio";
    desktopName = "Android Studio";
    genericName = "Android IDE";
    comment = "Develop Android applications";
    exec = "android-studio %f";
    icon = "${androidStudio.passthru.unwrapped}/bin/studio.svg";
    categories = [ "Development" "IDE" ];
    startupWMClass = "jetbrains-studio";
  };
in
{
  home.packages = [
    androidStudioLauncher
    androidStudioDesktop
  ];
}
