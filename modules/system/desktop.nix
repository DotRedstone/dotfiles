# ---
# Module: Desktop Environment
# Description: Niri compositor, SDDM with KWin (Final Polish for Cursor)
# ---

{ pkgs, inputs, lib, ... }: {
  imports = [ inputs.silent-sddm.nixosModules.default ];

  # [Compositor & Display Manager]
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.system}.niri;
  };
  services.displayManager.defaultSession = "niri";

  services.displayManager.sddm = {
    enable = true;
    autoNumlock = true;
    wayland = {
      enable = true;
      compositor = "kwin";
    };
    extraPackages = [ pkgs.bibata-cursors ];
    settings = {
      Theme = {
        CursorTheme = "Bibata-Modern-Classic";
        CursorSize = 24;
      };
    };
  };

  # [Intel & Wayland Cursor Fix]
  systemd.services.display-manager.environment = {
    KWIN_FORCE_SW_CURSOR = "1";
    KWIN_DRM_USE_MODIFIERS = "0";
    XCURSOR_PATH = "/run/current-system/sw/share/icons";
    QT_WAYLAND_SHELL_INTEGRATION = "layer-shell";
  };

  programs.silentSDDM = {
    enable = true;
    theme = "rei";
  };

  # [Graphics & Drivers]
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
      intel-compute-runtime
    ];
  };

  # [XDG Portals]
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config.niri = {
      default = lib.mkForce [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = lib.mkForce [ "gnome" ];
    };
  };

  # [Services]
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.devmon.enable = true;
  services.tumbler.enable = true;
  programs.dconf.enable = true;

  # [Theming & Desktop Tools]
  environment.systemPackages = with pkgs; [ 
    bibata-cursors 
    polkit_gnome # Required for graphical sudo prompts
  ];

  # [Polkit Agent Service]
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };
}
