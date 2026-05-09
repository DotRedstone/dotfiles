# ---
# Module: Starship Layout
# Description: Minimalist "Warden" Capsule Prompt (Nerd Fonts only, No Emojis)
# Scope: Home Manager
# ---

{ ... }: {
  # [Layout Template]
  # Source for noctalia's generation script
  home.file.".config/starship/layout.toml".text = ''
    add_newline = false

    format = """$username$hostname$cmd_duration 󰜥 $directory $git_branch\n$character"""

    [username]
    show_always = true
    style_user = "bold bg:primary fg:black"
    style_root = "bold bg:error fg:black"
    format = "[](bold primary)[$user]($style)"
    disabled = false

    [hostname]
    ssh_only = false
    format = "[•$hostname](bold bg:primary fg:black)[](bold primary)"
    disabled = false

    [cmd_duration]
    min_time = 0
    format = " [](bold tertiary)[󰪢 $duration](bold bg:tertiary fg:black)[](bold tertiary)"

    [directory]
    style = "bold bg:secondary fg:black"
    truncation_length = 6
    truncation_symbol = " ••/"
    home_symbol = "  "
    read_only = "  "
    format = "[](bold secondary)[󰉋 $path]($style)[](bold secondary)"

    [directory.substitutions]
    "Desktop" = "  "
    "Documents" = "  "
    "Downloads" = "  "
    "Music" = " 󰎈 "
    "Pictures" = "  "
    "Videos" = "  "
    "GitHub" = " 󰊤 "
    ".dotfiles" = "  "

    [git_branch]
    style = "bold bg:primary fg:black"
    symbol = "󰘬"
    truncation_length = 12
    format = " [](bold primary)[$symbol $branch$all_status]($style)[](bold primary)"

    [git_status]
    disabled = false
    conflicted = " 󱓷 "
    ahead = " 󰁟 "
    behind = " 󰁞 "
    diverged = " 󰃻 "
    untracked = " ? "
    stashed = " 󰀦 "
    modified = " ! "
    staged = " + "
    renamed = " 󰒲 "
    deleted = " - "
    format = "$all_status"

    [character]
    success_symbol = "[   ](bold primary)"
    error_symbol = "[   ](bold error)"

    [package]
    disabled = true
  '';
}
