# ---
# Module: Office
# Description: Office suites and document tools
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    onlyoffice-desktopeditors
  ];
}
