# ---
# Module: Claude Code Switchboard
# Description: Installs and registers Anthropic Claude Code terminal agent with timezone spoofing
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  claude-wrapped = pkgs.symlinkJoin {
    name = "claude-code-with-alias";
    paths = [ pkgs.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      # 注入时区伪装：固定为洛杉矶时区，规避区域检测
      wrapProgram $out/bin/claude \
        --set TZ "America/Los_Angeles"

      # 额外提供 claude-code 别名软链接，保证输入 claude 或 claude-code 均可执行
      ln -s $out/bin/claude $out/bin/claude-code
    '';
  };
in
{
  home.packages = [
    claude-wrapped
  ];
}
