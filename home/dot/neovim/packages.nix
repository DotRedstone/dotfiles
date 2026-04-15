# ---
# Module: Neovim Dependencies
# Description: External binaries for LSP, Treesitter, and clipboard
# ---

{ pkgs, ... }: {
  home.packages = [
    # [Runtime]
    pkgs.nodejs_22
    pkgs.tree-sitter

    # [Clipboard]
    pkgs.wl-clipboard

    # [LSP & Tooling]
    # Removed nodePackages prefix entirely
    pkgs.lua-language-server
    pkgs.stylua
    pkgs.prettier
    pkgs.pyright
  ];
}
