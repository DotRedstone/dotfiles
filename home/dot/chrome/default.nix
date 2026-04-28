# ---
# Module: Google Chrome
# Description: Chrome profile behavior aligned with Firefox defaults
# ---

{ pkgs, ... }:

{
  imports = [
    ./settings.nix
  ];

  programs.google-chrome = {
    enable = true;
    package = pkgs.google-chrome;
  };
}
