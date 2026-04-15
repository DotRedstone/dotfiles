# ---
# Module: Nautilus Settings
# Description: Dconf overrides for GTK interface and file manager behavior
# ---

{ lib, ... }: {
  dconf.settings = {
    # [Global GTK Interface]
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      # Force empty theme to let Libadwaita take control (standard for modern GNOME apps)
      gtk-theme = lib.mkForce "";
    };

    # [Nautilus Preferences]
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "icon-view";
      search-filter-time-type = "last_modified";
    };

    # [Archive Behavior]
    "org/gnome/nautilus/compression" = {
      full-path = true;
    };
  };
}
