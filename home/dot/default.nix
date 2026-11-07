# ---
# Module: Home Switchboard
# Description: Unified entry point for all Home Manager modules for user 'dot'
# Scope: Home Manager
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
    ./desktop-shells
    ./default-apps
    ./activitywatch
    ./autoclicker
    ./theme
    ./fcitx5
    ./cli-tools
    ./monitoring
    ./maintenance

    # --- File Management & Networking ---
    ./yazi
    ./dolphin
    ./ssh
    ./box-proxy
    ./secrets

    # --- Daily Applications ---
    ./firefox
    ./chrome
    ./zen-browser
    ./wechat
    ./telegram
    ./qq
    ./netease-music
    ./zathura
    ./office
    ./obsidian
    ./obs
    ./multimedia
    ./piclist
    ./rustdesk
    ./codex
    ./claude-desktop
    ./workbuddy
    ./univpn
    ./grok-bot
    ./kdeconnect
    ./downloads

    # --- Development & Security ---
    ./nixvim
    ./vscode
    ./dev
    ./antigravity
    ./claude-code
    ./security

    # --- Game ---
    ./axolotl
    ./mangohud
    ./steam
  ];

  # [Identity]
  home = {
    username = "dot";
    homeDirectory = "/home/dot";
    stateVersion = "24.11";
    sessionPath = [
      "$HOME/.local/npm-global/bin"
    ];
  };

  # [Home Services]
  programs.home-manager.enable = true;
  services.cliphist.enable = false;

  # [Packages]
  # Empty by design; generic tools are in cli-tools, apps are in their own modules.
  home.packages = [ ];
}
