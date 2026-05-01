# ---
# Module: User Management
# Description: User definition for 'dot' and system shell configuration
# Scope: System
# Notes:
# - mutableUsers is disabled; password hashes must be managed in /persist/secrets
# ---

{ pkgs, ... }: {
  users.mutableUsers = false;

  users.users.root = {
    # DO NOT write real password hashes here.
    # Use mkpasswd -m sha-512 | sudo tee /persist/secrets/root.passwd
    hashedPasswordFile = "/persist/secrets/root.passwd";
  };

  users.users.dot = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "network" "netdev" "video" "audio" "docker" "libvirtd" "input" ];
    # DO NOT write real password hashes here.
    # Use mkpasswd -m sha-512 | sudo tee /persist/secrets/dot.passwd
    hashedPasswordFile = "/persist/secrets/dot.passwd";
  };

  programs.fish.enable = true;

  # [Global Toolchain]
  environment.systemPackages = with pkgs; [
    neovim git wget curl unzip 
    python3 # Critical for Noctalia scripts
    kitty
  ];
}
