# ---
# Module: Users - Accounts
# Description: User definitions, groups, and password hash management
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
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEIMinPjcyubjQ8l0RPC8EgwoUXw/6UWAI6BmOz7A0Do codex-remote-access@33109"
    ];
    # DO NOT write real password hashes here.
    # Use mkpasswd -m sha-512 | sudo tee /persist/secrets/dot.passwd
    hashedPasswordFile = "/persist/secrets/dot.passwd";
  };
}
