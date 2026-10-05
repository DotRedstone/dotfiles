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

      # [Server Deployment Completions]
      complete -c deploy-server -f -a "hopper conduit target gcp-free" -d "受管服务器"
      complete -c rebuild-server -f -a "hopper conduit target gcp-free" -d "受管服务器"
    '';

    # [Functions]
    functions = {
      deploy-server = {
        description = "Deploy configuration to remote server using nh";
        body = ''
          if test (count $argv) -lt 1
              echo "用法: deploy-server <server> [额外参数]"
              echo "受管服务器: hopper, conduit, target, gcp-free"
              return 1
          end

          set -l host $argv[1]
          set -l extra $argv[2..-1]

          echo "==> 正在使用 nh 推送配置至 $host..."
          nh os switch ~/.dotfiles/servers \
              -H $host \
              --target-host "dot@$host" \
              --build-host "dot@$host" \
              -d never \
              -e passwordless \
              $extra
        '';
      };

      rebuild-server = {
        description = "Deploy configuration to remote server using nixos-rebuild";
        body = ''
          if test (count $argv) -lt 1
              echo "用法: rebuild-server <server> [额外参数]"
              echo "受管服务器: hopper, conduit, target, gcp-free"
              return 1
          end

          set -l host $argv[1]
          set -l extra $argv[2..-1]

          echo "==> 正在使用 nixos-rebuild 推送至 $host..."
          nixos-rebuild switch \
              --flake "path:$HOME/.dotfiles/servers#$host" \
              --target-host "dot@$host" \
              --build-host "dot@$host" \
              --elevate sudo \
              $extra
        '';
      };
    };

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
      # Status
      gst   = "git status";
      gss   = "git status --short";

      # Add
      ga    = "git add";
      gaa   = "git add -A";
      gap   = "git add -p";

      # Commit
      gcm   = "git commit -m";
      gca   = "git commit --amend";
      gcan  = "git commit --amend --no-edit";

      # Diff
      gd    = "git diff";
      gds   = "git diff --staged";

      # Branch
      gb    = "git branch";
      gba   = "git branch -a";
      gbd   = "git branch -d";
      gbD   = "git branch -D";

      # Switch
      gsw   = "git switch";
      gsc   = "git switch -c";

      # Fetch / Pull / Push
      gf    = "git fetch";
      gfa   = "git fetch --all --prune";
      gpl   = "git pull --ff-only";
      gps   = "git push";
      gpsu  = "git push -u origin HEAD";
      gpf   = "git push --force-with-lease";

      # Rebase / Merge
      grb   = "git rebase";
      grbi  = "git rebase -i";
      grbc  = "git rebase --continue";
      grba  = "git rebase --abort";
      gm    = "git merge";

      # Stash
      gsta  = "git stash push";
      gstaa = "git stash push -u";
      gstl  = "git stash list";
      gstp  = "git stash pop";

      # Log
      gl    = "git log --oneline --graph --decorate";
      gla   = "git log --oneline --graph --decorate --all";
      gls   = "git log --stat";

      # Undo
      gundo = "git reset --soft HEAD~1";

      # --- NixOS Management (nh/nrs) ---
      nrs    = "nh os switch -H warden ~/.dotfiles";
      nrb    = "nh os boot -H warden ~/.dotfiles";
      nsl    = "sudo nix-env -p /nix/var/nix/profiles/system --list-generations";
      nsd    = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations";
      nclean = "nh clean all --keep 5";
      nconf  = "cd ~/.dotfiles && nvim";

      # --- Server Deployment (nh) ---
      nrss        = "deploy-server";
      nrs-hopper  = "deploy-server hopper";
      nrs-conduit = "deploy-server conduit";
      nrs-target  = "deploy-server target";
      nrs-gcp     = "deploy-server gcp-free";

      # --- Home Manager (nh/hms) ---
      hms = "nh home switch ~/.dotfiles";
      hml = "home-manager generations";
      hme = "home-manager expire-generations \"-0 days\"";

      # --- Zellij ---
      zn  = "zellij --new-session-with-layout";
      za  = "zellij attach";
      zl  = "zellij list-sessions";
      zk  = "zellij kill-session";
      zka = "zellij kill-all-sessions";
      zd  = "zellij delete-session";
      zda = "zellij delete-all-sessions";

      # --- Btrfs Maintenance ---
      bmt = "sudo mount /dev/nvme0n1p5 /mnt -o subvolid=5";
      bsl = "sudo btrfs subvolume list /";
      bsd = "sudo btrfs subvolume delete --recursive";
      bq  = "sudo btrfs qgroup show -re --human-readable /";
      bqr = "sudo btrfs quota rescan /";
    };
  };
}
