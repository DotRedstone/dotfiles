# ---
# Module: Desktop - Niri
# Description: Niri compositor system-level enablement
# Scope: System
# Notes:
# - package 固定取 flake 输入的主线快照，而不是 pkgs.niri（nixpkgs 的 26.04 标签）。
#   home/dot/niri/config.kdl 里用的是 `max-bpc`，该配置项在 26.04 之后才进入主线，
#   改回 pkgs.niri 会直接导致配置解析失败。升级 flake 输入时需同时验证该文件的解析。
# ---

{ pkgs, inputs, ... }:
{
  programs.niri = {
    enable = true;
    useNautilus = false;
    # Upstream niri now ships the SHM (memfd) screencasting fallback and uses
    # libdisplay-info 0.3 directly, so the previous local patch/override is gone.
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };

  services.displayManager.defaultSession = "niri";
}
