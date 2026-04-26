# ---
# Module: Nixvim Configuration
# Description: Atomized Neovim configuration replacing the old LazyVim setup
# ---

{ pkgs, ... }: {
  imports = [
    ./packages.nix
    ./options.nix
    ./keymaps.nix
    ./plugins.nix
    ./theme.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # [Providers]
    withPython3 = true;
    withRuby = false;
    withNodeJs = true;

    # [Extra Binaries]
    extraPackages = with pkgs; [
      gcc
      gnumake
      unzip
      ripgrep
      fd
    ];
  };
}
