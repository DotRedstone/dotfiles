# ---
# Module: Python Development
# Description: Minimal Python interpreter and modern Rust-based tooling
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    # [Interpreter]
    python3

    # [LSP & Static Analysis]
    pyright # Microsoft's type checker for Neovim

    # [The Modern Choice: Ruff]
    # Replaces Black, Flake8, and Isort. It's written in Rust and extremely fast.
    ruff
  ];
}
