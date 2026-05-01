# ---
# Module: Theme Switchboard
# Description: Unified entry for UI assets, GTK/QT styling, and cursor sets
# Scope: Home Manager
# ---

{
  imports = [
    ./packages.nix
    ./gtk.nix
    ./qt.nix
    ./cursor.nix
  ];
}
