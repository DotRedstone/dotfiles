# ---
# Module: Modern CLI Tools
# Description: Next-generation terminal utilities, file manager, and consistent aliases
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    fd
    ripgrep
    xh
    btop
    duf
    dust
  ];

  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    icons = "auto";
    git = true;
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Mocha";
      italic-text = "always";
    };
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  programs.tealdeer = {
    enable = true;
    settings = {
      display = {
        compact = false;
        use_pager = true;
      };
    };
  };

  programs.lazygit.enable = true;

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";
  };

  home.shellAliases = {
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";
    lt = "eza --tree";
    cat = "bat --paging=never";
    cd = "z";
    grep = "rg";
    find = "fd";
    df = "duf";
    ds = "dust";
    curl = "xh";
  };
}
