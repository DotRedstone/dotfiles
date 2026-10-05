# ---
# Module: OBS Packages
# Description: OBS Studio wrapped with the Bilibili Stream plugin
# Scope: Home Manager
# ---

{ pkgs, ... }:

let
  obsBilibiliStream = pkgs.qt6Packages.callPackage ./bilibili-stream.nix { };

  obsStudio = pkgs.wrapOBS {
    plugins = [ obsBilibiliStream ];
  };
in
{
  home.packages = [ obsStudio ];
}
