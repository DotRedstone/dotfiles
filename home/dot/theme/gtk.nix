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
      name = "adw-gtk3-dark";
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

  # [Dynamic CSS Injection]
  # Symlinking system config to matugen/noctalia cache for real-time updates
  xdg.configFile = {
    "gtk-4.0/gtk.css".source = lib.mkForce 
      (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/gtk-4.0.css");
    
    "gtk-4.0/gtk-dark.css".source = lib.mkForce 
      (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/gtk-4.0.css");
    
    "gtk-3.0/gtk.css".source = lib.mkForce 
      (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/gtk-3.0.css");
  };
}
