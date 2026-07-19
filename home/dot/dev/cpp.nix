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
    llvmPackages.openmp
    mpich
    mpich.dev

    # [Build Systems]
    cmake
    gnumake

    # [LSP & Tooling]
    clang-tools # Provides clangd for Neovim
  ];

  xdg.configFile."clangd/config.yaml".text = ''
    CompileFlags:
      Add:
        - -fopenmp
        - -isystem
        - ${pkgs.llvmPackages.openmp.dev}/include
  '';
}
