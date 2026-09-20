# ---
# Module: Linux Kernel Research
# Description: Kernel build, virtualization, and debugging tools for local research
# Scope: Home Manager
# ---

{ lib, pkgs, ... }:
let
  guestRuntimeDeps = with pkgs; [
    bash
    busybox
    coreutils
    util-linux
    gnugrep
    gnused
    iproute2
    kmod
    kbd
    shadow
    socat
    systemd
  ];

  guestRuntimePath = lib.makeBinPath guestRuntimeDeps;

  virtme-ng = pkgs.python3Packages.buildPythonApplication rec {
    pname = "virtme-ng";
    version = "1.41";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "arighi";
      repo = "virtme-ng";
      rev = "v${version}";
      hash = "sha256-/R+2ND/N+exF9eDSxAN8LR3cDuxBvpGSkiXcckyq8TY=";
    };

    # The guest runs this script as PID 1 and NixOS has no /bin/bash.
    # /nix/store remains visible in virtme-ng's copy-on-write host root.
    postPatch = ''
      substituteInPlace virtme/guest/virtme-init \
        --replace-fail '#!/bin/bash' '#!${pkgs.bash}/bin/bash'
      substituteInPlace virtme/guest/virtme-init \
        --replace-fail 'export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin' \
        'export PATH=${guestRuntimePath}'
    '';

    build-system = with pkgs.python3Packages; [
      argparse-manpage
      setuptools
    ];

    dependencies = with pkgs.python3Packages; [
      argcomplete
      requests
    ];

    doCheck = false;
  };

  pkgConfigDeps = with pkgs; [
    openssl.dev
    elfutils.dev
    ncurses.dev
  ];

  pkgConfigPath = lib.makeSearchPath "lib/pkgconfig" pkgConfigDeps;

  kernelPkgConfig = pkgs.symlinkJoin {
    name = "kernel-pkg-config";
    paths = [ pkgs.pkg-config ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/pkg-config" \
        --prefix PKG_CONFIG_PATH : "${pkgConfigPath}"
    '';
  };
in
{
  home.packages = with pkgs; [
    # [Kernel Build]
    gcc
    binutils
    gnumake
    bc
    flex
    bison
    perl
    python3
    kernelPkgConfig
    openssl
    openssl.dev
    elfutils
    elfutils.dev
    ncurses
    ncurses.dev
    pahole
    cpio
    rsync
    zstd
    xz
    gzip
    bzip2
    file

    # [Virtualization]
    qemu
    virtme-ng
    virtiofsd
    kmod
    iproute2

    # [Kernel Diagnostics]
    perf
    gdb
    trace-cmd
    strace
  ];

  # pkg-config is intentionally scoped to the headers required for kernel builds.
  home.sessionVariables.PKG_CONFIG_PATH = pkgConfigPath;
}
