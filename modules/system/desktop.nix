# ---
# Module: Desktop Environment
# Description: Niri compositor, SDDM with KWin (Final Polish for Cursor)
# ---

{ pkgs, inputs, lib, ... }:

let
  sddmStateDir = "/var/lib/sddm";

  sddmKcminputrc = pkgs.writeText "sddm-kcminputrc" ''
    [Keyboard]
    NumLock=0
  '';

  sddmKwinrc = pkgs.writeText "sddm-kwinrc" ''
    [Keyboard]
    NumLock=0
  '';
in {
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
      General = {
        Numlock = "on";
      };
      Theme = {
        CursorTheme = "Bibata-Modern-Classic";
        CursorSize = 24;
      };
    };
  };

  # SDDM's NixOS autoNumlock option writes General/Numlock=on into sddm.conf,
  # which is enough for the X11 greeter path. The Wayland greeter starts KWin
  # as the sddm user instead, and KWin initializes keyboard state from that
  # user's KDE config in $HOME/.config. NixOS creates the sddm home at
  # /var/lib/sddm, so seed the same NumLock preference there before the greeter
  # starts. In KDE's keyboard config, NumLock=0 means "turn NumLock on".
  systemd.tmpfiles.rules = [
    "d ${sddmStateDir} 0755 sddm sddm -"
    "d ${sddmStateDir}/.config 0750 sddm sddm -"
    "C+ ${sddmStateDir}/.config/kcminputrc 0644 sddm sddm - ${sddmKcminputrc}"
    "C+ ${sddmStateDir}/.config/kwinrc 0644 sddm sddm - ${sddmKwinrc}"
    "z ${sddmStateDir} 0755 sddm sddm -"
    "z ${sddmStateDir}/.config 0750 sddm sddm -"
    "z ${sddmStateDir}/.config/kcminputrc 0644 sddm sddm -"
    "z ${sddmStateDir}/.config/kwinrc 0644 sddm sddm -"
  ];

  # [Intel & Wayland Cursor Fix]
  systemd.services.display-manager = {
    # tmpfiles runs during activation, but an already persisted /var/lib/sddm can
    # keep stale ownership. Reinstall these files immediately before SDDM starts
    # so KWin reads the NumLock config from an sddm-owned HOME every boot.
    preStart = ''
      ${pkgs.coreutils}/bin/install -d -o sddm -g sddm -m 0755 ${sddmStateDir}
      ${pkgs.coreutils}/bin/install -d -o sddm -g sddm -m 0750 ${sddmStateDir}/.config
      ${pkgs.coreutils}/bin/install -o sddm -g sddm -m 0644 ${sddmKcminputrc} ${sddmStateDir}/.config/kcminputrc
      ${pkgs.coreutils}/bin/install -o sddm -g sddm -m 0644 ${sddmKwinrc} ${sddmStateDir}/.config/kwinrc
    '';

    environment = {
      KWIN_FORCE_SW_CURSOR = "1";
      KWIN_DRM_USE_MODIFIERS = "0";
      XCURSOR_PATH = "/run/current-system/sw/share/icons";
      QT_WAYLAND_SHELL_INTEGRATION = "layer-shell";
    };
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
    QT_QPA_PLATFORMTHEME = "qt6ct";
    LANG = "zh_CN.UTF-8";
    LANGUAGE = "zh_CN:zh";
  };
}
