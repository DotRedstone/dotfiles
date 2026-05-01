# ---
# Module: Modern CLI & TUI Tools
# Description: Next-generation terminal utilities and file managers
# ---

{ config, lib, pkgs, ... }: {
  # Standard Packages (Tools without complex config modules)
  home.packages = with pkgs; [
    fd          # Modern find
    ripgrep     # Modern grep
    xh          # Modern curl
    btop        # System monitor (Managed by Noctalia)
    
    # Aesthetics
    cbonsai
    cmatrix
    pipes-rs
  ];

  # [Modern Coreutils]
  
  # Eza: Modern replacement for ls
  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    icons = "auto";
    git = true;
  };

  # Bat: Modern replacement for cat
  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Mocha";
      italic-text = "always";
    };
  };

  # Zoxide: Modern replacement for cd
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # FZF: Command-line fuzzy finder
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    colors = {
      "bg+" = "#313244";
      "bg" = "#1e1e2e";
      "spinner" = "#f5e0dc";
      "hl" = "#f38ba8";
      "fg" = "#cdd6f4";
      "header" = "#f38ba8";
      "info" = "#cba6f7";
      "pointer" = "#f5e0dc";
      "marker" = "#b4befe";
      "fg+" = "#cdd6f4";
      "prompt" = "#cba6f7";
      "hl+" = "#f38ba8";
    };
  };

  # Tealdeer: Fast tldr client (man page replacement)
  programs.tealdeer = {
    enable = true;
    settings = {
      display = {
        compact = false;
        use_pager = true;
      };
      updates = {
        auto_update = true;
      };
    };
  };

  # Lazygit: Git terminal UI
  programs.lazygit = {
    enable = true;
  };

  xdg.configFile."lazygit/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/lazygit.yml";
  home.file."${config.xdg.configHome}/lazygit/config.yml" = {
    enable = lib.mkForce true;
    source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/lazygit.yml"
    );
  };

  # [Fastfetch Config]
  xdg.configFile."fastfetch/config.jsonc".source = ./fastfetch.json;

  # Shell aliases to map classic commands to modern ones
  home.shellAliases = {
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";
    lt = "eza --tree";
    cat = "bat";
    cd = "z";
    grep = "rg";
    find = "fd";
  };
}
