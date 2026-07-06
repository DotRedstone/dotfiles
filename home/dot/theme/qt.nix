# ---
# Module: QT Configuration
# Description: Forces QT applications to follow GTK styling
# Scope: Home Manager
# ---

{ ... }:
{
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };
}
