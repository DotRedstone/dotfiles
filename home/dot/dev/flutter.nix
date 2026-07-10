# ---
# Module: Flutter Development
# Description: Flutter SDK command-line tools for mobile application development
# Scope: Home Manager
# ---

{ config, pkgs, ... }:
let
  flutterSdkPath = "${config.home.homeDirectory}/.local/share/flutter-sdk";
in
{
  home.packages = [
    pkgs.flutter
  ];

  home.file.".local/share/flutter-sdk".source = pkgs.flutter;

  home.sessionVariables = {
    FLUTTER_ROOT = flutterSdkPath;
  };
}
