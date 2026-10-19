# ---
# Module: WorkBuddy Switchboard
# Description: Installs and registers WorkBuddy desktop application
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  workbuddy = pkgs.callPackage ./package.nix { };
in
{
  home.packages = [
    workbuddy
  ];
}
