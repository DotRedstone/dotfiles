# ---
# Module: App - RustDesk
# Description: Remote desktop client (Flutter version)
# Scope: Home Manager
# Notes:
# - RustDesk 1.5.0 的 libsodium-sys 需要系统 libsodium；上游 nixpkgs 尚未补上
#   buildInputs，构建会报 "The system library `libsodium` was not found"。
#   等 nixpkgs 修复后可删除下面的 override。
# ---

{ pkgs, ... }:
let
  rustdesk = pkgs.rustdesk-flutter.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.libsodium ];
  });
in
{
  home.packages = [
    rustdesk
  ];
}
