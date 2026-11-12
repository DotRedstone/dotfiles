# ---
# Module: Claude Code Switchboard
# Description: Installs and registers Anthropic Claude Code terminal agent with timezone spoofing
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  # nixpkgs 暂时落后于上游发布；本地 pin 到最新已验证版本，等 nixpkgs 追上后删除。
  claudeCodeLatest = pkgs.claude-code.overrideAttrs (old: {
    version = "2.1.322";
    src = pkgs.fetchurl {
      url = "https://downloads.claude.ai/claude-code-releases/2.1.322/linux-x64/claude.zst";
      hash = "sha256-m7dVi9mSykV+ZFi/FoZXL3oxVrgzHdhEM5Hb/lkMHu0=";
    };
  });

  claude-wrapped = pkgs.symlinkJoin {
    name = "claude-code-with-alias";
    paths = [ claudeCodeLatest ];
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
