# ---
# Module: Desktop - Services
# Description: Desktop-agnostic system services (Keyring, GVFS, UDisks, dconf)
# Scope: System
# ---

{ pkgs, ... }: {
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.devmon.enable = true;
  services.tumbler.enable = true;
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [ 
    libsecret # Secret Service helpers for apps such as VS Code
    seahorse # GUI for inspecting/unlocking GNOME keyrings
  ];
}
