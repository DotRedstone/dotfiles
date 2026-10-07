# ---
# Module: Hopper Jupyter Environment Tools
# Description: Bin paths for Jupyter PDF export and single-user terminal toolchains
# Scope: Host
# ---

{ lib, pkgs, ... }:

let
  jupyterPdfExportPath = lib.makeBinPath [
    pkgs.pandoc
    pkgs.texliveFull
  ];

  jupyterToolPath = lib.makeBinPath [
    pkgs.gcc
    pkgs.gnumake
    pkgs.pkg-config
    pkgs.binutils
    pkgs.nodejs
    pkgs.jdk
    pkgs.git
    pkgs.zip
    pkgs.unzip
    pkgs.tree
    pkgs.file
  ];
in {
  _module.args.jupyterPaths = {
    inherit jupyterPdfExportPath jupyterToolPath;
  };
}
