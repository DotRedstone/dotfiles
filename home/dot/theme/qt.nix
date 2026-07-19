# ---
# Module: QT Configuration
# Description: Provides dark Qt theming for shell-launched and systemd-launched apps
# Scope: Home Manager
# ---

{ config, pkgs, ... }:

let
  qt5PluginPath = "${config.home.profileDirectory}/${pkgs.qt5.qtbase.qtPluginPrefix}";
  qt6PluginPath = "${config.home.profileDirectory}/${pkgs.qt6.qtbase.qtPluginPrefix}";

  qtctCommon = colorSchemePath: ''
    [Appearance]
    color_scheme_path=${colorSchemePath}
    custom_palette=true
    icon_theme=Papirus-Dark
    standard_dialogs=default
    style=Fusion

    [Fonts]
    fixed="Maple Mono NF,11,-1,5,50,0,0,0,0,0"
    general="Maple Mono NF,11,-1,5,50,0,0,0,0,0"

    [Interface]
    activate_item_on_single_click=1
    buttonbox_layout=0
    cursor_flash_time=1000
    dialog_buttons_have_icons=1
    double_click_interval=400
    gui_effects=@Invalid()
    keyboard_scheme=2
    menus_have_icons=true
    show_shortcuts_in_context_menus=true
    stylesheets=@Invalid()
    toolbutton_style=4
    underline_shortcut=1
    wheel_scroll_lines=3
  '';
in
{
  qt = {
    enable = true;
    platformTheme.name = "qt5ct";
    style.name = "Fusion";
  };

  xdg.configFile."qt5ct/qt5ct.conf".text =
    qtctCommon "${config.home.homeDirectory}/.config/qt5ct/colors/noctalia.conf";

  xdg.configFile."qt6ct/qt6ct.conf".text =
    qtctCommon "${config.home.homeDirectory}/.config/qt6ct/colors/noctalia.conf";

  xdg.configFile."environment.d/10-qt-theme.conf".text = ''
    QT_QPA_PLATFORM=wayland;xcb
    QT_QPA_PLATFORMTHEME=qt5ct
    QT_STYLE_OVERRIDE=Fusion
    QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    QT_PLUGIN_PATH=${qt5PluginPath}:${qt6PluginPath}
  '';
}
