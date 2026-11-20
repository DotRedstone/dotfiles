# ---
# Module: Antigravity Tools
# Description: Antigravity 多账号管理与切换客户端（含配额看板与缓存优先会话）
# Scope: Home Manager
# Notes:
# - 上游会在首次运行时把 ~/.local/bin/at 指向 AppImage 解包出的未包装二进制，
#   那个二进制在 NixOS 上无法启动。这里用 home.file 覆盖成转发到包装版的脚本；
#   若应用再次改写该文件，重跑 home-manager switch 即可恢复。
# - 包装版支持子命令（list/current/switch/sync），不依赖 argv[0]，因此无需 at 别名机制。
# ---

{ pkgs, ... }:

let
  antigravity-tools = pkgs.callPackage ./package.nix { };
in {
  home.packages = [ antigravity-tools ];

  home.file.".local/bin/at" = {
    text = ''
      #!/bin/sh
      # Antigravity Tools CLI 的 NixOS 兼容入口，见本模块 Notes。
      exec ${antigravity-tools}/bin/antigravity-tools "$@"
    '';
    executable = true;
    force = true;
  };

  # 应用首次运行还会把 ~/.local/bin/antigravity-tools 指向同一个未包装二进制，
  # 而 ~/.local/bin 在 PATH 中优先于 nix-profile，会盖掉可用版本，故一并接管。
  home.file.".local/bin/antigravity-tools" = {
    text = ''
      #!/bin/sh
      exec ${antigravity-tools}/bin/antigravity-tools "$@"
    '';
    executable = true;
    force = true;
  };
}
