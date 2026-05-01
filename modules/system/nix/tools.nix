# ---
# Module: Nix - Tools
# Description: Nix-related CLI tools for system management and troubleshooting
# Scope: System
# ---

{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    nh
    nix-output-monitor
    nvd
    sops
    age
  ];
}
