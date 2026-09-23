# ---
# Module: NixVim - Core
# Description: Neovim enablement, aliases, and global variables
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  programs.nixvim = {
    enable = true;
    nixpkgs.useGlobalPackages = true;

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    withPython3 = true;
    withRuby = false;
    withNodeJs = true;

    extraPackages = with pkgs; [
      gcc
      gnumake
      unzip
      ripgrep
      fd
      git
      curl
      nodejs
    ];

    globals = {
      mapleader = " ";
      maplocalleader = " ";
      loaded_netrw = 1;
      loaded_netrwPlugin = 1;
      markdown_recommended_style = 0;
    };
  };

  xdg.desktopEntries.nvim = {
    name = "Neovim";
    genericName = "文本编辑器";
    comment = "编辑文本文件";
    exec = "nvim %F";
    icon = "nvim";
    terminal = true;
    categories = [ "Utility" "TextEditor" "Development" ];
    mimeType = [ "text/plain" ];
  };
}
