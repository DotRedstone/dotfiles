# ---
# Module: Modern CLI & TUI Tools
# Description: Next-generation terminal utilities and file managers
# ---

{ pkgs, ... }: {
  # Standard Packages (Tools without complex config modules)
  home.packages = with pkgs; [
    fd          # Modern find
    ripgrep     # Modern grep
    xh          # Modern curl
    
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
    settings = {
      gui.theme = {
        activeBorderColor = [ "#b4befe" "bold" ];
        inactiveBorderColor = [ "#6c7086" ];
        optionsTextColor = [ "#89b4fa" ];
        selectedLineBgColor = [ "#313244" ];
        cherryPickedCommitBgColor = [ "#45475a" ];
        cherryPickedCommitFgColor = [ "#b4befe" ];
        unstagedChangesColor = [ "#f38ba8" ];
        defaultFgColor = [ "#cdd6f4" ];
        searchingActiveBorderColor = [ "#f9e2af" ];
      };
    };
  };

  # Btop: System monitor with Catppuccin theme
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "catppuccin_mocha";
      theme_background = false; # Use terminal background
      vim_keys = true;
    };
  };

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
