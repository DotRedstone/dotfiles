# ---
# Module: NetEase Cloud Music GTK
# Description: NetEase Cloud Music GTK client (Rust/GTK4)
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = [
    pkgs.netease-cloud-music-gtk
  ];
}
