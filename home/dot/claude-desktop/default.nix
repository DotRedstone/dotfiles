# ---
# Module: Claude Desktop
# Description: 以本机 nixpkgs 重建 Claude Desktop 并修补 Linux 浏览器登录回调
# Scope: Home Manager
# ---
#
# Notes:
# - 上游 flake 自带的 nixpkgs 较旧，其 Electron 链接的 glibc 无法加载系统
#   /run/opengl-driver 中的新版 Mesa，GPU 加速会退回软件渲染。因此只复用上游
#   配方，在本仓库 nixpkgs 中构建；不修改 flake.lock。
# - 浏览器登录回调依赖浏览器和 xdg-desktop-portal 识别 claude.desktop。二者
#   都在启动时缓存应用列表，Home Manager 切换后不会刷新。首次安装后需重启
#   浏览器，并运行 `systemctl --user restart xdg-desktop-portal`；否则浏览器
#   把 claude:// 当作未知协议，或 portal 弹出空的“打开方式”对话框。
# - 系统浏览器登录流程中，Desktop 不会转圈等待；收到 claude://login 回调后
#   才完成登录。

{ pkgs, inputs, ... }:
let
  upstreamSrc = inputs.claude-desktop-linux;

  patchy-cnb = pkgs.callPackage "${upstreamSrc}/pkgs/patchy-cnb.nix" { };

  claude-desktop = (pkgs.callPackage "${upstreamSrc}/pkgs/claude-desktop.nix" {
    inherit patchy-cnb;
    # 上游原用 Electron 35，当前 nixpkgs 已移除且更早的受支持版本均已 EOL，
    # 因此跟随 nixpkgs 默认 Electron。
    inherit (pkgs) electron;
    # nodePackages 已从 nixpkgs 移除，上游配方只用到其中的 asar。
    nodePackages = { inherit (pkgs) asar; };
  }).overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.nodejs ];

    # 上游 buildPhase 结束时位于 electron-app/，解包目录 app.asar.contents 仍在。
    postBuild = ''
      node ${./patch-auth.js} app.asar.contents/.vite/build/index.js
      asar pack app.asar.contents app.asar
    '';

    postInstall = ''
      # 固定时区，规避区域检测；清除外部 LD_LIBRARY_PATH，避免 second-instance
      # 加载不兼容的 glibc；xdg-utils 供 shell.openExternal 使用。
      wrapProgram $out/bin/claude-desktop \
        --unset LD_LIBRARY_PATH \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]} \
        --set TZ "America/Los_Angeles"
    '';
  });
in
{
  home.packages = [ claude-desktop ];
}
