# ---
# Module: Beacon Home Manager Environment
# Description: User CLI environment, shell utilities, and dotfiles for user dot on beacon
# Scope: Home Manager
# ---

{ pkgs, ... }:

{
  # [Home State]
  home.username = "dot";
  home.homeDirectory = "/Users/dot";
  home.stateVersion = "24.11";

  # [CLI Packages]
  home.packages = with pkgs; [
    # Shell & Navigation
    fd
    ripgrep
    fzf
    jq
    tmux
    htop
    btop
    tree

    # Networking & Dev Tools
    curl
    wget
    git
    rsync
  ];

  # [Git Baseline]
  programs.git = {
    enable = true;
    settings.user = {
      name = "DotRedstone";
      email = "dotredstone@outlook.com";
    };
  };

  # [Zsh Configuration]
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };
}
