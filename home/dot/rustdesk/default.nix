# ---
# Module: App - RustDesk
# Description: Remote desktop client (Flutter version)
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = [
    pkgs.rustdesk-flutter
  ];
}
