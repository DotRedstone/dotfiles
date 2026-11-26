# ---
# Module: C/C++ Development
# Description: GCC, GDB, CMake, Ninja, GNU Make, pkg-config, and clangd
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    gcc
    gdb
    cmake
    ninja
    gnumake
    pkg-config
    clang-tools
  ];
}
