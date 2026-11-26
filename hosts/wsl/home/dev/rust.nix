# ---
# Module: Rust Development
# Description: Rust compiler, cargo, rust-analyzer, clippy, and rustfmt
# Scope: Home Manager
# ---

{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt
  ];

  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
  ];
}
