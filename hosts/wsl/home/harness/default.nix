# ---
# Module: WSL Harness Switchboard
# Description: AI coding agent CLIs and the herdr runtime for WSL
# Scope: Home Manager
# ---
# Notes:
# - claude-code 复用 home/dot/claude-code；不要引入 Codex 或 Antigravity 桌面客户端。

{ ... }: {
  imports = [
    ./herdr.nix
    ./skillshare.nix
    ../../../../home/dot/claude-code
    ./codex.nix
    ./cursor.nix
    ./pi.nix
    ./agy.nix
  ];
}
