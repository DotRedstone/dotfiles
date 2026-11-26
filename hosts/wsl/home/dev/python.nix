# ---
# Module: Python Development
# Description: Python interpreter, uv package manager, ruff, and pyright
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    python3
    uv
    ruff
    pyright
  ];
}
