# ---
# Module: Home Entry
# Description: Main Home Manager configuration for 'dot'
# ---

{ inputs, ... }: {
  # [Imports]
  imports = [
    # --- External Modules ---
    inputs.noctalia.homeModules.default

    # --- Shell & Terminal ---
    ./fish
    ./starship
    ./zellij
    ./wezterm
    # ./kitty (Optional/Disabled)
    
    # --- Desktop & System UI ---
    ./niri
    ./noctalia
    ./theme
    ./fcitx5
    ./cli-tools

    # --- File Management & Networking ---
    ./yazi
    ./nautilus
    ./flclash
    ./ssh

    # --- Daily Applications ---
    ./firefox
    ./wechat
    ./telegram
    ./netease-music

    # --- Development ---
    ./neovim
    ./vscode
    ./dev
  ];

  # [Identity]
  home = {
    username = "dot";
    homeDirectory = "/home/dot";
    stateVersion = "24.11";
  };

  # [Home Services]
  programs.home-manager.enable = true;
  services.cliphist.enable = true; # Clipboard history manager

  # [Packages]
  # Empty by design; generic tools are in cli-tools, apps are in their own modules.
  home.packages = [ ];
}
