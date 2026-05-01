# ---
# Module: Fish Shell Configuration
# Description: Interactive shell settings, abbreviations, and plugins
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  programs.fish = {
    enable = true;

    # [Plugins]
    plugins = [
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "done"; src = pkgs.fishPlugins.done.src; }
      { name = "colored-man-pages"; src = pkgs.fishPlugins.colored-man-pages.src; }
    ];

    # [Interactive Init]
    interactiveShellInit = ''
      set -g fish_greeting
      fish_vi_key_bindings
      # [Environment Variables]
      set -gx NH_NOM 1     # Enable pretty output for NH
      set -gx NH_FLAKE /home/dot/.dotfiles # Standard flake for NH
      set -gx NH_SEARCH_CHANNEL nixpkgs-unstable # Try to fix nh search
      
      # FZF with Bat preview
      set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border --preview 'bat --style=numbers --color=always --line-range :500 {}'"

      # Custom bind: jk to escape insert mode
      bind -M insert jk "set fish_bind_mode default; commandline -f backward-char force-repaint"
    '';

    # [Abbreviations]
    shellAbbrs = {
      # --- Modern Replacements ---
      ns   = "nix search nixpkgs";
      cat  = "bat --paging=never --color=never --decorations=never";
      grep = "rg";
      df   = "duf";
      curl = "xh";
      tl   = "tldr";
      ds   = "dust";

      # --- Eza (ls enhancements) ---
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first --git";
      la = "eza -la --icons --group-directories-first --git";
      lt = "eza --tree --icons";

      # --- Git Operations ---
      gs     = "git status";
      ga     = "git add";
      gc     = "git commit -m";
      gp     = "git push";
      gl     = "git log --oneline --graph --decorate";
      gbc    = "git checkout -b";     # Create and switch to new branch
      gbm    = "git merge";          # Merge branch
      gamend = "git commit --amend --no-edit"; # Fix last commit
      gundo  = "git reset --soft HEAD~1";      # Undo last commit (keep changes)

      # --- NixOS Management (nh/nrs) ---
      nrs    = "nh os switch -H warden ~/.dotfiles";
      nrb    = "nh os boot -H warden ~/.dotfiles";
      nsl    = "sudo nix-env -p /nix/var/nix/profiles/system --list-generations";
      nsd    = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations";
      nclean = "nh clean all --keep 5";
      nconf  = "cd ~/.dotfiles && nvim";

      # --- Home Manager (nh/hms) ---
      hms = "nh home switch ~/.dotfiles";
      hml = "home-manager generations";
      hme = "home-manager expire-generations \"-0 days\"";

      # --- Btrfs Maintenance ---
      bmt = "sudo mount /dev/nvme0n1p5 /mnt -o subvolid=5";
      bsl = "sudo btrfs subvolume list /";
      bsd = "sudo btrfs subvolume delete --recursive";
      bq  = "sudo btrfs qgroup show -re --human-readable /";
      bqr = "sudo btrfs quota rescan /";
    };
  };
}
