# ---
# Module: Network - Mihomo
# Description: Run a locally controlled Mihomo core without a standalone proxy GUI
# Scope: System
# Notes:
# - The controller is intentionally loopback-only for the Noctalia plugin.
# - TUN remains configuration-owned; importing a profile does not change the default route.
# ---

{ pkgs, ... }:

let
  stateDir = "/var/lib/mihomo";
  configPath = "${stateDir}/config.yaml";

  mihomoProfileImport = pkgs.writeShellApplication {
    name = "mihomo-profile-import";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
    ];
    text = ''
      set -eu

      source_path="''${1:-}"
      if [ -z "$source_path" ]; then
        echo "用法: sudo mihomo-profile-import <Mihomo YAML 配置路径>" >&2
        exit 64
      fi

      if [ "$(id -u)" -ne 0 ]; then
        echo "请通过 sudo 运行，以保护配置中的订阅地址。" >&2
        exit 77
      fi

      if [ ! -f "$source_path" ] || [ ! -r "$source_path" ]; then
        echo "无法读取配置文件: $source_path" >&2
        exit 66
      fi

      # A supplied controller can have a non-local binding or secret. Do not
      # silently replace either: this installer is only for profiles without a
      # controller, such as the old FlClash profile.
      if ${pkgs.gnugrep}/bin/grep -Eq '^(external-controller|secret):' "$source_path"; then
        echo "配置已定义 external-controller 或 secret；请手动审计后再迁移。" >&2
        exit 65
      fi

      ${pkgs.coreutils}/bin/install -d -m 0700 "${stateDir}/backups"
      temporary_path="$(mktemp "${stateDir}/config.yaml.XXXXXX")"
      cleanup() {
        rm -f "$temporary_path"
      }
      trap cleanup EXIT

      ${pkgs.coreutils}/bin/install -m 0600 "$source_path" "$temporary_path"
      ${pkgs.coreutils}/bin/printf '\n# Managed locally for Noctalia Mihomo Control.\nexternal-controller: 127.0.0.1:9090\n' >> "$temporary_path"

      backup_path=""
      if [ -f "${configPath}" ]; then
        backup_path="${stateDir}/backups/config.$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ).yaml"
        ${pkgs.coreutils}/bin/cp -p "${configPath}" "$backup_path"
      fi

      ${pkgs.coreutils}/bin/mv -f "$temporary_path" "${configPath}"
      trap - EXIT

      if ! ${pkgs.systemd}/bin/systemctl restart mihomo.service; then
        if [ -n "$backup_path" ]; then
          ${pkgs.coreutils}/bin/cp -p "$backup_path" "${configPath}"
          ${pkgs.systemd}/bin/systemctl restart mihomo.service || true
        fi
        echo "Mihomo 未能启动；已保留原配置备份。" >&2
        exit 1
      fi

      echo "Mihomo 配置已导入。Noctalia 控制器: http://127.0.0.1:9090"
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.mihomo
    mihomoProfileImport
  ];

  # The profile contains private provider URLs, so it is root-owned and lives
  # in a persisted service state directory rather than in the Nix store.
  systemd.services.mihomo = {
    description = "Mihomo local proxy core";
    documentation = [ "https://wiki.metacubex.one/" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = configPath;

    serviceConfig = {
      Type = "simple";
      StateDirectory = "mihomo";
      StateDirectoryMode = "0700";
      WorkingDirectory = stateDir;
      ExecStart = "${pkgs.mihomo}/bin/mihomo -d ${stateDir} -f ${configPath}";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";

      # Keep enough privileges for a future profile-owned TUN stanza without
      # granting access to arbitrary host paths.
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ stateDir ];
    };
  };
}
