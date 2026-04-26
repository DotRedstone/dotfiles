# ---
# Module: GTK Configuration
# Description: Standardizes GTK3/4 behavior and links to Noctalia-generated CSS
# ---

{ config, pkgs, lib, customPapirus, ... }: {
  gtk = {
    enable = true;
    
    # [GTK4 Override]
    # Forcing null to prevent pre-packaged themes from overriding custom CSS
    gtk4.theme = lib.mkForce null;

    theme = {
      name = "adw-gtk3";
      package = pkgs.adw-gtk3;
    };

    iconTheme = { 
      name = "Papirus-Dark"; 
      package = customPapirus; 
    };

    cursorTheme = { 
      name = "Bibata-Modern-Classic"; 
      package = pkgs.bibata-cursors; 
      size = 24; 
    };
  };


  # [Force Dark Preference]
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3";
    };
  };
}
