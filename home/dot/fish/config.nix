# ---
# Module: Fish Shell Configuration
# Description: Interactive shell settings, abbreviations, and plugins
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
      # Custom bind: jk to escape insert mode
      bind -M insert jk "set fish_bind_mode default; commandline -f backward-char force-repaint"
    '';

    # [Abbreviations]
    shellAbbrs = {
      # --- Modern Replacements ---
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

      # --- NixOS Management (nrs) ---
      nrs    = "sudo nixos-rebuild switch --flake ~/.dotfiles#warden";
      nrb    = "sudo nixos-rebuild boot --flake ~/.dotfiles#warden";
      nsl    = "sudo nix-env -p /nix/var/nix/profiles/system --list-generations";
      nsd    = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations";
      nclean = "sudo nix-collect-garbage -d && nix-collect-garbage -d";
      nconf  = "cd ~/.dotfiles && nvim";

      # --- Home Manager (hms) ---
      hms = "home-manager switch --flake ~/.dotfiles#\"dot@warden\"";
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
