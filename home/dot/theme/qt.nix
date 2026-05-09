# ---
# Module: QT Configuration
# Description: Forces QT applications to follow GTK styling
# Scope: Home Manager
# ---

{ ... }: {
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };
}
