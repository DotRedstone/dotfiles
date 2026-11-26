# ---
# Module: Dynamic Linker Compatibility
# Description: Enable nix-ld with common libraries for VS Code Remote-WSL and prebuilt binaries
# Scope: System
# ---

{ pkgs, ... }: {
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      curl
      glib
      icu
      nss
      nspr
      expat
      libxcrypt-legacy
    ];
  };
}
