# ---
# Module: WSL Fish Shell
# Description: Interactive fish configuration with vi bindings, plugins, and WSL nh abbreviations
# Scope: Home Manager
# ---
# Notes:
# - 本文件只服务 WSL。不要把这些缩写写进 home/dot/fish/config.nix。
# - NH_FLAKE 指向 /home/${profile.username}/.dotfiles；nrs/nrb 使用 -H wsl。

{ pkgs, profile, ... }: {
  programs.fish = {
    enable = true;

    plugins = [
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "done"; src = pkgs.fishPlugins.done.src; }
      { name = "colored-man-pages"; src = pkgs.fishPlugins.colored-man-pages.src; }
    ];

    interactiveShellInit = ''
      set -g fish_greeting
      fish_vi_key_bindings

      set -gx NH_NOM 1
      set -gx NH_FLAKE /home/${profile.username}/.dotfiles

      bind -M insert jk "set fish_bind_mode default; commandline -f backward-char force-repaint"
    '';

    shellAbbrs = {
      # [Git]
      gst = "git status";
      gss = "git status --short";
      ga  = "git add";
      gaa = "git add -A";
      gcm = "git commit -m";
      gd  = "git diff";
      gds = "git diff --staged";
      gsw = "git switch";
      gpl = "git pull --ff-only";
      gps = "git push";
      gl  = "git log --oneline --graph --decorate";

      # [NH & Nix]
      nrs    = "nh os switch -H wsl ~/.dotfiles";
      nrb    = "nh os boot -H wsl ~/.dotfiles";
      nclean = "nh clean all --keep 3";
      ns     = "nix search nixpkgs";

      # [Harness]
      hd  = "herdr";
      hdl = "herdr list";
      hda = "herdr attach";

      # [Zellij]
      zj  = "zellij";
      zn  = "zellij --new-session-with-layout";
      za  = "zellij attach";
      zl  = "zellij list-sessions";
      zk  = "zellij kill-session";
    };
  };
}
