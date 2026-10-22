# ---
# Module: App - KDE Connect
# Description: KDE Connect service and indicator for cross-device integration
# Scope: Home Manager
# ---

{ ... }: {
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };
}
