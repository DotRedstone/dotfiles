# ---
# Module: WSL Editor Switchboard
# Description: Entry point for the lightweight terminal editor on WSL
# Scope: Home Manager
# ---
# Notes:
# - 使用轻量 neovim，不引入 home/dot/nixvim。

{ ... }: {
  imports = [
    ./neovim.nix
  ];
}
