# ---
# Module: Telegram
# Description: Official Telegram Desktop client with Wayland and QT input optimizations
# ---

{ pkgs, ... }: {
  # [Packages]
  home.packages = [ pkgs.telegram-desktop ];

  # [Environment Variables]
  # Optimized for Wayland/Niri and Fcitx5 Chinese input
  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_IM_MODULE = "fcitx";
    # Optional: Fix for some QT6 apps if fcitx doesn't trigger
    # QT_IM_MODULES = "fcitx;ibus"; 
  };
}
