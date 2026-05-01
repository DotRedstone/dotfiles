# ---
# Module: Users - Core Tools
# Description: Essential system packages and global toolchain
# Scope: System
# ---

{ pkgs, ... }: {
  # [Global Toolchain]
  environment.systemPackages = with pkgs; [
    neovim git wget curl unzip 
    python3 # Critical for Noctalia scripts
    kitty
  ];
}
