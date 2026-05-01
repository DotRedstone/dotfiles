# ---
# Module: NixVim Plugins Switchboard
# Description: Imports all atomized plugin groups
# ---

{ ... }: {
  imports = [
    ./ui.nix
    ./editor.nix
    ./navigation.nix
    ./lsp.nix
    ./formatting.nix
    ./git.nix
    ./completion.nix
    ./treesitter.nix
  ];
}
