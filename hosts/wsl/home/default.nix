# ---
# Module: WSL Home Switchboard
# Description: Unified entry point for the WSL Home Manager user environment
# Scope: Home Manager
# ---
# Notes:
# - 不要 import ../../dot 或 home/dot/default.nix。
# - claude-code 复用 home/dot/claude-code（无桌面依赖）；不要引入 Codex/Antigravity 桌面模块。

{ profile, ... }: {
  imports = [
    ./shell
    ./cli
    ./dev
    ./harness
    ./editor
  ];

  home = {
    username = profile.username;
    homeDirectory = "/home/${profile.username}";
    stateVersion = "24.11";
  };

  programs.home-manager.enable = true;
}
