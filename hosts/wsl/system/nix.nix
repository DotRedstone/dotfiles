# ---
# Module: Nix & NH Maintenance
# Description: Flake settings, domestic substituters, nh helper, and garbage collection
# Scope: System
# ---
# Notes:
# - programs.nh.flake 必须指向 /home/${profile.username}/.dotfiles，不要写成独立仓 ~/nixos-wsl，也不要写死 /home/dot/.dotfiles。
# - 不要把这个值同步到 warden；warden 的 NH_FLAKE 在 home/dot/fish/config.nix。

{ profile, ... }: {
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" profile.username ];
      substituters = [
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
        "https://cache.nixos.org"
      ];
    };
  };

  # [NH]
  # 统一的系统更新与旧代清理前端；-H 与 nixosConfigurations.wsl 及 hostname 一致
  programs.nh = {
    enable = true;
    flake = "/home/${profile.username}/.dotfiles";
    clean = {
      enable = true;
      extraArgs = "--keep-since 7d --keep 3";
    };
  };
}
