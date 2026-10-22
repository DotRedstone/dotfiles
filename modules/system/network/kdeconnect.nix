# ---
# Module: Network - KDE Connect
# Description: Enables KDE Connect system integration and opens firewall ports
# Scope: System
# ---

{ ... }: {
  programs.kdeconnect.enable = true;
}
