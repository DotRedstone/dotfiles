# ---
# Module: Box Nix Settings
# Description: 声明云电脑用户级 nix.conf（启用 nix-command 与 flakes）
# Scope: Home Manager
# Notes:
# - 直接写 nix.conf 而不用 nix.settings：后者要求由 Home Manager 指定 nix.package，会切换 profile 中已装的 nix 版本。
# ---
{ ... }:
{
  xdg.configFile."nix/nix.conf".text = ''
    experimental-features = nix-command flakes
  '';
}
