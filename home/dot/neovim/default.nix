# ---
# Module: Neovim Core
# Description: Main Neovim configuration and provider settings
# ---

{ pkgs, ... }: {
  imports = [ ./packages.nix ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # [Providers]
    withPython3 = true;
    withRuby = false;
    withNodeJs = true;

    # [Internal Toolchain]
    extraPackages = with pkgs; [
      gcc
      gnumake
      unzip
      ripgrep
      fd
    ];
  };
}
