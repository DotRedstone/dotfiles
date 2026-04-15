# ---
# Module: Starship Layout
# Description: Structural configuration for the prompt segments
# ---

{ ... }: {
  # [Layout Template]
  # Source for noctalia's generation script
  home.file.".config/starship/layout.toml".text = ''
    [character]
    success_symbol = "[󰄬](primary bold) "
    error_symbol = "[󰅖](error bold) "

    [directory]
    style = "primary bold"
    truncation_length = 3
    fish_style_pwd_dir_length = 1

    [git_branch]
    symbol = " "
    style = "secondary bold"

    [git_status]
    style = "error bold"
    format = "([$all_status$ahead_behind]($style) )"

    [hostname]
    ssh_only = false
    format = "[@$hostname](tertiary bold) "

    [cmd_duration]
    style = "secondary bold"
    format = "took [$duration]($style) "

    [status]
    disabled = true
  '';
}
