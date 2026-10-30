# ---
# Module: Grok Bot Switchboard
# Description: Installs and registers Grok Bot desktop application
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  grok-bot = pkgs.callPackage ./package.nix { };
in
{
  home.packages = [
    grok-bot
  ];
}
