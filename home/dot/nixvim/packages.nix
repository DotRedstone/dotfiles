# ---
# Module: Neovim Dependencies
# Description: External binaries for LSP, Treesitter, and clipboard
# ---

{ pkgs, ... }: {
  home.packages = [
    # [Runtime]
    pkgs.tree-sitter

    # [Clipboard]
    pkgs.wl-clipboard

    # [Tooling]
    pkgs.stylua
    pkgs.prettier
    pkgs.ripgrep
    pkgs.fd
  ];
}
