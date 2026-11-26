# ---
# Module: WSL Development Switchboard
# Description: Language toolchains for the WSL host without Warden-only Android or kernel modules
# Scope: Home Manager
# ---
# Notes:
# - 不要 import ../../../dot/dev/default.nix，以免带入 android、flutter、kernel。

{ ... }: {
  imports = [
    ./python.nix
    ./node.nix
    ./go.nix
    ./rust.nix
    ./cpp.nix
    ./java.nix
  ];
}
