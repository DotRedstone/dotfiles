# ---
# Module: User Management
# Description: User definition for 'dot' and system shell
# ---

{ pkgs, ... }: {
  users.mutableUsers = false;

  users.users.root = {
    hashedPasswordFile = "/persist/secrets/root.passwd";
  };

  users.users.dot = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "network" "netdev" "video" "audio" "docker" "libvirtd" "input" ];
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
