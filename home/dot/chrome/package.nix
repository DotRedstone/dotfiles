# ---
# Module: Chrome - Package
# Description: Enablement and package definition for Google Chrome
# ---

{ pkgs, ... }: {
  programs.google-chrome = {
    enable = true;
    package = pkgs.google-chrome;
  };
}
