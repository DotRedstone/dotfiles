# ---
# Module: UniVPN Switchboard
# Description: Installs and registers UniVPN desktop application
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  univpn = pkgs.callPackage ./package.nix { };
in
{
  home.packages = [
    univpn
  ];
}
