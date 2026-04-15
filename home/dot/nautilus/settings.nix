# ---
# Module: Nautilus Settings
# Description: Dconf overrides for GTK interface and file manager behavior
# ---

{ config, lib, ... }: {
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
      default-compression-format = "zip";
    };
  };

  # [GTK Bookmarks]
  gtk.gtk3.bookmarks = [
    "file://${config.home.homeDirectory}/Downloads 下载"
    "file://${config.home.homeDirectory}/Pictures 图片"
    "file://${config.home.homeDirectory}/Videos 视频"
    "file://${config.home.homeDirectory}/Documents 文档"
    "file://${config.home.homeDirectory}/Music 音乐"
    "file://${config.home.homeDirectory}/.dotfiles Dotfiles"
  ];
}
