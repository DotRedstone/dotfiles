# ---
# Module: Desktop - SDDM
# Description: SDDM display manager and SilentSDDM theme configuration
# Scope: System
# ---

{ pkgs, inputs, ... }: {
  imports = [ inputs.silent-sddm.nixosModules.default ];

  services.displayManager.sddm = {
    enable = true;
    autoNumlock = true;
    wayland = {
      enable = true;
      compositor = "kwin";
    };
    extraPackages = [ pkgs.bibata-cursors ];
    settings = {
      General = {
        Numlock = "on";
      };
      Theme = {
        CursorTheme = "Bibata-Modern-Classic";
        CursorSize = 24;
      };
    };
  };

  programs.silentSDDM = {
    enable = true;
    theme = "rei";
  };

  # SDDM Wayland/KWin environment fixes
  systemd.services.display-manager = {
    environment = {
      KWIN_FORCE_SW_CURSOR = "1";
      KWIN_DRM_USE_MODIFIERS = "0";
      XCURSOR_PATH = "/run/current-system/sw/share/icons";
      QT_WAYLAND_SHELL_INTEGRATION = "layer-shell";
    };
  };
}
