# ---
# Module: C/C++ Development
# Description: Toolchain for systems programming and competitive programming
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    # [Compilers & Debuggers]
    gcc
    gdb

    # [Build Systems]
    cmake
    gnumake

    # [LSP & Tooling]
    clang-tools # Provides clangd for Neovim
  ];
}
