# ---
# Module: User Management
# Description: User definition for 'dot' and system shell
# ---

{ pkgs, ... }: {
  users.users.dot = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" "libvirtd" "input" ];
  };

  programs.fish.enable = true;

  # [Global Toolchain]
  environment.systemPackages = with pkgs; [
    neovim git wget curl unzip 
    python3 # Critical for Noctalia scripts
    kitty
  ];
}
