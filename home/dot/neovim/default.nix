# ---
# Module: Neovim Core
# Description: Neovim configuration with LazyVim bootstrap
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

    # [Bootstrap]
    initLua = ''
      -- bootstrap lazy.nvim, LazyVim and your plugins
      require("config.lazy")
    '';

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
