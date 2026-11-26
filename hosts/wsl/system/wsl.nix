# ---
# Module: WSL Baseline
# Description: Core NixOS-WSL settings, default user, and optional runtime switches
# Scope: System
# ---

{ lib, pkgs, profile, ... }: {
  networking.hostName = profile.hostName;

  wsl = {
    enable = true;
    defaultUser = profile.username;
    startMenuLaunchers = true;

    # 允许在 WSL 内直接调用 Windows 侧 .exe
    interop.register = true;

    wslConf = {
      automount.enabled = true;
      network.generateResolvConf = true;
    };

    # 需在 WSL 内使用宿主机 NVIDIA GPU 时在 profile.nix 开启
    useWindowsDriver = profile.enableCudaDriver;
  };

  users.users.${profile.username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ] ++ lib.optionals profile.enableDocker [ "docker" ];
  };

  programs.fish.enable = true;
  security.sudo.wheelNeedsPassword = false;

  virtualisation.docker.enable = profile.enableDocker;

  # 减小镜像体积，保留基础网络与核心命令行工具
  documentation.nixos.enable = false;

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim
  ];

  system.stateVersion = "24.11";
}
