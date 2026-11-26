# ---
# Module: WSL Host Entry
# Description: Assemble the NixOS-WSL system and a dedicated Home Manager user environment
# Scope: Host
# ---
# Notes:
# - 不要引入 modules/system 或 home/dot 的 switchboard；桌面、impermanence 与 SOPS SSH 不属于 WSL。
# - WSL 的 nrs 使用 -H wsl；不要改 home/dot/fish/config.nix 里 warden 的缩写。

{ inputs, profile, ... }: {
  imports = [
    ./system
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs profile; };
    users.${profile.username} = import ./home;
  };
}
