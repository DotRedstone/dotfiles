# ---
# Module: WSL Profile Parameters
# Description: User identity, hostname, and optional Docker/CUDA toggles for the WSL host
# Scope: Host
# ---
# Notes:
# - 默认身份与独立仓 DotRedstone/nixos-wsl 的 profiles.nix 原值一致，供他人使用。
# - networking.hostName 为 nixos-wsl；flake 属性名与 nh -H 仍为 wsl，不要改成 nixos-wsl。

{
  username = "nixos";
  hostName = "nixos-wsl";
  timeZone = "Asia/Shanghai";

  gitName = "NixOS User";
  gitEmail = "user@example.com";

  # 按需开启重型功能：默认关闭以保持基础 WSL 镜像精简
  enableDocker = false;
  enableCudaDriver = false;
}
