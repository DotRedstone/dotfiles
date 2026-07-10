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
    export STUDIO_PROPERTIES="$HOME/.config/android-studio/idea.properties"
    export STUDIO_VM_OPTIONS="$HOME/.config/android-studio/studio64.vmoptions"

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

  xdg.configFile."android-studio/idea.properties".text = ''
    sun.java2d.xrender=false
    ide.browser.jcef.gpu.disable=true
    ide.ui.new.ui.custom.decorations.on.linux=true
  '';

  xdg.configFile."android-studio/studio64.vmoptions".text = ''
    -Dawt.toolkit.name=WLToolkit
  '';
}
