# ---
# Host: Beacon
# Description: macOS system-level configuration for Mac Mini M4 (Apple Silicon)
# ---

{ pkgs, ... }: {
  # [System Services]
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
  system.stateVersion = 5;

  # [Shell Integration]
  programs.fish.enable = true;

  # [System Packages]
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
  ];

  # [User Configuration]
  users.users.dot = {
    name = "dot";
    home = "/Users/dot";
    shell = pkgs.fish;
  };

  # [macOS Preferences]
  system.defaults = {
    dock.autohide = true;
    dock.mru-spaces = false;
    finder.AppleShowAllExtensions = true;
    finder.FXPreferredViewStyle = "clmv";
    NSGlobalDomain.AppleShowAllExtensions = true;
    NSGlobalDomain.InitialKeyRepeat = 15;
    NSGlobalDomain.KeyRepeat = 2;
  };
}
