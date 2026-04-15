# ---
# Module: Modern CLI Tools
# Description: Rust-powered alternatives and shell integrations
# ---

{ pkgs, ... }: {
  # [Modern Replacements]
  home.packages = with pkgs; [
    eza         # ls
    bat         # cat
    fd          # find
    ripgrep     # grep
    bottom      # htop (btm)
    procs       # ps
    duf         # df
    dust        # du
    tealdeer    # man (tldr)
    xh          # curl (HTTPie-like)
    gping       # visual ping
  ];

  # [Shell Integrations]
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  # [The Environment Engine]
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableFishIntegration = true;
  };
}
