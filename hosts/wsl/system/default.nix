# ---
# Module: WSL System Switchboard
# Description: Unified entry point for NixOS-WSL system modules
# Scope: System
# ---
# Notes:
# - 字体与 warden 共用 modules/system/fonts.nix，不要在本目录再复制一份。

{ ... }: {
  imports = [
    ./wsl.nix
    ./nix.nix
    ./nix-ld.nix
    ./locale.nix
    ./sshd.nix
    ../../../modules/system/fonts.nix
  ];
}
