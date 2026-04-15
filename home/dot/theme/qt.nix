# ---
# Module: QT Configuration
# Description: Forces QT applications to follow GTK styling
# ---

{ ... }: {
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };
}
