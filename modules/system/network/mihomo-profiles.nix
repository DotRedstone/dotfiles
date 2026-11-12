# ---
# Module: Mihomo Profile Library
# Description: 为 Noctalia 提供受限的本机配置导入和持久切换接口
# Scope: System
# Notes:
# - 仅固定的 root helper 可读写私有配置库；插件只接触 JSON 元数据。
# - 导入来源限定为 dot 的 Downloads，且不会自动启用或启动服务。
# ---

{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  implementation = pkgs.replaceVars ./mihomo-profile-helper.py {
    mihomo = "${pkgs.mihomo}/bin/mihomo";
    bwrap = "${pkgs.bubblewrap}/bin/bwrap";
    systemctl = "${pkgs.systemd}/bin/systemctl";
  };
  rootHelper = pkgs.writeShellScriptBin "mihomo-profile-root" ''
    exec ${python}/bin/python3 -I ${implementation} "$@"
  '';
  userHelper = pkgs.writeShellScriptBin "mihomo-profile-helper" ''
    exec /run/wrappers/bin/pkexec ${rootHelper}/bin/mihomo-profile-root "$@"
  '';
in
{
  environment.systemPackages = [ userHelper ];

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.policykit.exec" &&
          subject.user == "dot" &&
          action.lookup("program") == "${rootHelper}/bin/mihomo-profile-root") {
        return polkit.Result.YES;
      }
    });
  '';
}
