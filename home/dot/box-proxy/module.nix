# ---
# Module: Box Proxy
# Description: Provide an opt-in local Mihomo proxy and isolated Chrome launcher
# Scope: Home Manager
# ---
# Notes:
# - Both entry points are opt-in; Chrome requires the proxy module.
# - Subscription URLs are runtime input only and never enter the Nix store.

{ config, lib, pkgs, ... }:
let
  cfg = config.programs.box-proxy;
  locale = lib.replaceStrings [ "-" ] [ "_" ] cfg.chrome.lang;
  boxProxy = pkgs.writeShellApplication {
    name = "box-proxy";
    runtimeInputs = [ pkgs.coreutils pkgs.curl pkgs.python3 ];
    text = ''
      set -euo pipefail
      D="$HOME/.local/state/box-proxy"; PIDF="$D/mihomo.pid"
      MIH="''${BOX_PROXY_MIHOMO:-${lib.getExe cfg.package}}"
      PX="http://127.0.0.1:7890"
      alive() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }
      case "''${1:-status}" in
        on)
          alive && { echo "already running (pid $(cat "$PIDF"))"; exit 0; }
          [ -f "$D/config.yaml" ] || { echo "no config; run: box-proxy refresh" >&2; exit 1; }
          umask 077; mkdir -p "$D"; chmod 700 "$D"
          nohup "$MIH" -d "$D" -f "$D/config.yaml" >"$D/mihomo.log" 2>&1 & echo $! >"$PIDF"
          chmod 600 "$PIDF" "$D/mihomo.log"
          sleep 3
          alive && echo "on: $PX (pid $(cat "$PIDF"))" || { echo "failed to start" >&2; exit 1; }
          ;;
        off)
          if alive; then kill "$(cat "$PIDF")"; rm -f "$PIDF"; echo off; else echo "not running"; fi
          ;;
        status)
          if alive; then echo "running pid $(cat "$PIDF"), listen $PX"; else echo "stopped"; fi
          ;;
        refresh)
          : "''${BOX_PROXY_SUBSCRIPTION_URL:?BOX_PROXY_SUBSCRIPTION_URL not set}"
          umask 077; mkdir -p "$D"; chmod 700 "$D"
          printf 'url = "%s"\n' "$BOX_PROXY_SUBSCRIPTION_URL" | curl -sS -K - --max-time 30 -o "$D/raw.bin" -f
          chmod 600 "$D/raw.bin"
          python3 - <<'PY'
      import json, os
      d = os.path.expanduser("~/.local/state/box-proxy")
      with open(d + "/raw.bin", encoding="utf-8") as f:
          config = json.load(f)
      config["bind-address"] = "127.0.0.1"
      config["mixed-port"] = 7890
      config["allow-lan"] = False
      tun = config.get("tun")
      if not isinstance(tun, dict):
          tun = {}
      tun["enable"] = False
      config["tun"] = tun
      path = d + "/config.yaml"
      if os.path.exists(path):
          os.remove(path)
      fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
      os.write(fd, json.dumps(config, indent=2, ensure_ascii=False).encode())
      os.close(fd)
      PY
          "$MIH" -t -d "$D" -f "$D/config.yaml" >/dev/null 2>&1 && echo "config ok (restart with: box-proxy off; box-proxy on)"
          ;;
        run)
          shift; alive || { echo "proxy is off; run: box-proxy on" >&2; exit 1; }
          NP="localhost,127.0.0.1,::1"
          exec env http_proxy="$PX" https_proxy="$PX" all_proxy="$PX" HTTP_PROXY="$PX" HTTPS_PROXY="$PX" ALL_PROXY="$PX" no_proxy="$NP" NO_PROXY="$NP" "$@"
          ;;
        *) echo "usage: box-proxy {on|off|status|refresh|run <cmd...>}" >&2; exit 2 ;;
      esac
    '';
  };
  boxChrome = pkgs.writeShellApplication {
    name = "box-chrome";
    runtimeInputs = [ boxProxy pkgs.gnugrep ];
    text = ''
      box-proxy status | grep -q running || { echo "proxy is off; run: box-proxy on" >&2; exit 1; }
      export TZ=${lib.escapeShellArg cfg.chrome.timeZone}
      export LANG=${lib.escapeShellArg "${locale}.UTF-8"}
      exec ${lib.escapeShellArg cfg.chrome.executable} \
        --lang=${lib.escapeShellArg cfg.chrome.lang} \
        --force-webrtc-ip-handling-policy=disable_non_proxied_udp \
        --user-data-dir="$HOME/.local/state/box-chrome" \
        --proxy-server="http://127.0.0.1:7890" \
        --proxy-bypass-list="localhost;127.0.0.1" "$@"
    '';
  };
in {
  options.programs.box-proxy = {
    enable = lib.mkEnableOption "用户级 Mihomo 代理";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mihomo;
      description = "box-proxy 使用的 Mihomo 包。";
    };
    chrome = {
      enable = lib.mkEnableOption "通过 box-proxy 运行的独立 Chrome 启动器";
      executable = lib.mkOption {
        type = lib.types.str;
        default = "google-chrome";
        description = "Chrome 可执行文件名或路径；模块不会安装 Chrome。";
      };
      timeZone = lib.mkOption {
        type = lib.types.str;
        default = "America/Los_Angeles";
        description = "box-chrome 进程使用的时区。";
      };
      lang = lib.mkOption {
        type = lib.types.str;
        default = "en-US";
        description = "传递给 Chrome --lang 的语言标识。";
      };
    };
  };
  config = {
    assertions = [{
      assertion = !cfg.chrome.enable || cfg.enable;
      message = "programs.box-proxy.chrome.enable requires programs.box-proxy.enable = true.";
    }];
    home.packages = lib.optionals cfg.enable ([ boxProxy ] ++ lib.optionals cfg.chrome.enable [ boxChrome ]);
  };
}
