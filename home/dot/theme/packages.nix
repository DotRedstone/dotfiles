# ---
# Module: Theme Assets
# Description: Icon sets, cursor packages, and theming engines
# ---

{ pkgs, ... }:

let
  customPapirus = pkgs.papirus-icon-theme.override {
    color = "brown";
  };
in
{
  home.packages = with pkgs; [
    customPapirus
    hicolor-icon-theme
    bibata-cursors
    adw-gtk3
    matugen
  ];

  # [Module Injection]
  # Allows other theme modules to reference the overridden icon package
  _module.args.customPapirus = customPapirus;
}
