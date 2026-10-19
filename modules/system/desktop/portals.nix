# ---
# Module: Desktop - Portals
# Description: XDG Desktop Portal configuration for Wayland compatibility
# Scope: System
# ---

{ pkgs, lib, ... }: {
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config.niri = {
      default = lib.mkForce [ "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = lib.mkForce [ "kde" ];
      "org.freedesktop.impl.portal.ScreenCast" = lib.mkForce [ "gnome" ];
    };
  };
}
