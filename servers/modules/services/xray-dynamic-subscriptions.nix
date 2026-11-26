# ---
# Module: Server Xray Dynamic Subscriptions
# Description: Render per-account Xray subscriptions combined with live preferred IP pools
# Scope: System
# ---
# Notes:
# - Reuses existing UUID, websocket_path, and reality_short_id_0 secrets declared by xrayNode.
# - Only declares new secrets (subscription path, preferred pool URL, and reality public key).

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.xrayDynamicSubscriptions;
  entryNames = builtins.attrNames cfg.entries;
  hasEntries = cfg.enable && entryNames != [ ];

  secretList = lib.unique (
    lib.concatMap (
      name:
      let
        entry = cfg.entries.${name};
      in
      [
        entry.pathSecret
        entry.preferredPoolUrlSecret
        entry.realityPublicKeySecret
      ]
    ) entryNames
  );

  pathSecrets = lib.unique (map (name: cfg.entries.${name}.pathSecret) entryNames);

  manifestData = lib.mapAttrs (
    name: entry: {
      accountName = entry.accountName;
      publicAddress = entry.publicAddress;
      realityPort = entry.realityPort;
      realityServerName = entry.realityServerName;
      cdnHost = entry.cdnHost;
      cdnPort = entry.cdnPort;
      poolLabel = entry.poolLabel;
      uuidPath = config.sops.secrets."xray/managed_${entry.accountName}_uuid".path;
      preferredPoolUrlPath = config.sops.secrets.${entry.preferredPoolUrlSecret}.path;
      realityPublicKeyPath = config.sops.secrets.${entry.realityPublicKeySecret}.path;
      realityShortIdPath = config.sops.secrets.${entry.realityShortIdSecret}.path;
      websocketPathFile = config.sops.secrets.${entry.websocketPathSecret}.path;
    }
  ) cfg.entries;

  manifestFile = pkgs.writeText "xray-dynamic-subscriptions-manifest.json" (
    builtins.toJSON manifestData
  );

  syncScript = pkgs.writeText "sync-xray-dynamic-subscriptions.py" ''
    import base64
    import json
    import os
    import pathlib
    import re
    import shutil
    import sys
    import urllib.parse
    import urllib.request

    STATE_DIR = pathlib.Path("/var/lib/xray-dynamic-subscriptions")
    ADDR_PATTERN = re.compile(r"^[A-Za-z0-9:.-]+$")
    BRACKETED_PATTERN = re.compile(r"^\[([^\]]+)\](?::(\d+))?$")
    HOST_PORT_PATTERN = re.compile(r"^([^:]+):(\d+)$")
    SPEED_PATTERN = re.compile(
        r"(?:^|-)([\d.]+\s*(?:[KMG]B/s|Mbps|kbps|MBps))$", re.IGNORECASE
    )


    def read_secret(path: str) -> str:
        return pathlib.Path(path).read_text(encoding="utf-8").strip()


    def format_host(addr: str) -> str:
        return f"[{addr}]" if ":" in addr else addr


    def parse_preferred_lines(raw_text: str) -> list[tuple[str, int, str]]:
        endpoints: list[tuple[str, int, str]] = []
        seen: set[str] = set()
        for line in raw_text.splitlines():
            trimmed = line.strip()
            if not trimmed or trimmed.startswith("#"):
                continue
            target_part, _, label_part = trimmed.partition("#")
            csv_parts = [p.strip() for p in target_part.split(",")]
            addr_part = csv_parts[0] if csv_parts else ""
            port = 443
            label = label_part or (csv_parts[2] if len(csv_parts) > 2 else "") or (
                csv_parts[1] if len(csv_parts) > 1 else ""
            )

            m_bracket = BRACKETED_PATTERN.match(addr_part)
            m_hostport = HOST_PORT_PATTERN.match(addr_part)
            if m_bracket:
                addr_part = m_bracket.group(1)
                if m_bracket.group(2):
                    port = int(m_bracket.group(2))
            elif m_hostport:
                addr_part = m_hostport.group(1)
                port = int(m_hostport.group(2))
            elif len(csv_parts) > 1 and csv_parts[1].isdigit():
                port = int(csv_parts[1])
                label = label_part or (csv_parts[2] if len(csv_parts) > 2 else "")

            addr = addr_part.strip().strip("[]")
            if not addr or len(addr) > 253 or not ADDR_PATTERN.match(addr):
                continue
            if port < 1 or port > 65535:
                continue

            key = f"{addr.lower()}:{port}"
            if key in seen:
                continue
            seen.add(key)
            endpoints.append((addr, port, label.strip()))
        return endpoints


    def fetch_preferred(url: str, cache_file: pathlib.Path) -> list[tuple[str, int, str]]:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
            endpoints = parse_preferred_lines(raw)
            if endpoints:
                tmp_cache = cache_file.with_suffix(".cache.tmp")
                tmp_cache.write_text(raw, encoding="utf-8")
                os.chmod(tmp_cache, 0o600)
                os.replace(tmp_cache, cache_file)
                return endpoints
        except Exception as exc:
            print(f"warn: preferred pool fetch failed ({exc.__class__.__name__}), using cache", file=sys.stderr)

        if cache_file.exists():
            cached_raw = cache_file.read_text(encoding="utf-8", errors="replace")
            return parse_preferred_lines(cached_raw)
        return []


    def preferred_node_name(pool_label: str, index: int, label: str) -> str:
        base = f"{pool_label}-优选-{index:02d}"
        m = SPEED_PATTERN.search(label)
        return f"{base}-{m.group(1)}" if m else base


    def render_entry(name: str, entry: dict) -> None:
        user_uuid = read_secret(entry["uuidPath"])
        pbk = read_secret(entry["realityPublicKeyPath"])
        sid = read_secret(entry["realityShortIdPath"])
        ws_path = read_secret(entry["websocketPathFile"])
        preferred_url = read_secret(entry["preferredPoolUrlPath"])

        pool_label = entry["poolLabel"]
        cdn_host = entry["cdnHost"]
        cdn_port = int(entry["cdnPort"])

        quoted_uuid = urllib.parse.quote(user_uuid, "")

        reality_query = urllib.parse.urlencode(
            {
                "encryption": "none",
                "security": "reality",
                "type": "tcp",
                "sni": entry["realityServerName"],
                "fp": "chrome",
                "pbk": pbk,
                "sid": sid,
            }
        )
        reality_name = urllib.parse.quote(f"{pool_label}-直连-Reality", "")
        reality_uri = (
            f"vless://{quoted_uuid}@"
            f"{format_host(entry['publicAddress'])}:{int(entry['realityPort'])}"
            f"?{reality_query}#{reality_name}"
        )

        ws_params = {
            "encryption": "none",
            "security": "tls",
            "type": "ws",
            "sni": cdn_host,
            "host": cdn_host,
            "path": ws_path,
            "fp": "chrome",
        }
        ws_query = urllib.parse.urlencode(ws_params)
        cf_direct_name = urllib.parse.quote(f"{pool_label}-CF-直连", "")
        cf_direct_uri = (
            f"vless://{quoted_uuid}@"
            f"{format_host(cdn_host)}:{cdn_port}"
            f"?{ws_query}#{cf_direct_name}"
        )

        uris = [reality_uri, cf_direct_uri]

        cache_file = STATE_DIR / f"{name}.preferred.cache"
        endpoints = fetch_preferred(preferred_url, cache_file)
        for idx, (addr, port, label) in enumerate(endpoints, start=1):
            node_name = urllib.parse.quote(preferred_node_name(pool_label, idx, label), "")
            uris.append(
                f"vless://{quoted_uuid}@"
                f"{format_host(addr)}:{port}"
                f"?{ws_query}#{node_name}"
            )

        encoded = base64.b64encode("\n".join(uris).encode("utf-8")).decode("ascii")
        out_file = STATE_DIR / f"{name}.txt"
        tmp_file = STATE_DIR / f".{name}.txt.tmp"
        tmp_file.write_text(encoded, encoding="utf-8")
        os.chmod(tmp_file, 0o640)
        shutil.chown(tmp_file, group="nginx")
        os.replace(tmp_file, out_file)
        print(f"rendered {name}: {len(uris)} endpoints")


    def main() -> int:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
        for name, entry in manifest.items():
            render_entry(name, entry)
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
  '';
in
{
  options.dot.services.xrayDynamicSubscriptions = {
    enable = lib.mkEnableOption "dynamic per-account Xray subscriptions synced with preferred pools";

    hostName = lib.mkOption {
      type = lib.types.str;
      description = "Existing Nginx virtual host serving the dynamic subscription endpoints.";
      example = "node.example.com";
    };

    entries = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              accountName = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Managed proxy account name in dot.proxyAccounts.accounts.";
              };

              publicAddress = lib.mkOption {
                type = lib.types.str;
                description = "Public IPv4/hostname for the direct REALITY endpoint.";
              };

              realityPort = lib.mkOption {
                type = lib.types.port;
                default = 20002;
                description = "Public VLESS REALITY port.";
              };

              realityServerName = lib.mkOption {
                type = lib.types.str;
                default = "www.nvidia.com";
                description = "TLS SNI configured for REALITY.";
              };

              cdnHost = lib.mkOption {
                type = lib.types.str;
                description = "Cloudflare-fronted WebSocket hostname.";
              };

              cdnPort = lib.mkOption {
                type = lib.types.port;
                default = 443;
                description = "Cloudflare-fronted WebSocket port.";
              };

              poolLabel = lib.mkOption {
                type = lib.types.str;
                default = "SG";
                description = "Display prefix for rendered subscription nodes.";
              };

              preferredPoolUrlSecret = lib.mkOption {
                type = lib.types.str;
                description = "SOPS secret key holding the preferred IP pool URL.";
              };

              realityPublicKeySecret = lib.mkOption {
                type = lib.types.str;
                default = "xray/reality_public_key";
                description = "SOPS secret key holding the REALITY client pbk.";
              };

              realityShortIdSecret = lib.mkOption {
                type = lib.types.str;
                default = "xray/reality_short_id_0";
                description = "SOPS secret key holding the REALITY shortId (declared by xrayNode).";
              };

              websocketPathSecret = lib.mkOption {
                type = lib.types.str;
                default = "xray/websocket_path";
                description = "SOPS secret key holding the WebSocket path (declared by xrayNode).";
              };

              pathSecret = lib.mkOption {
                type = lib.types.str;
                default = "xray/subscription_${name}_path";
                description = "SOPS secret key holding the HTTP location path for this subscription.";
              };
            };
          }
        )
      );
      default = { };
      description = "Dynamic per-account subscription definitions.";
    };
  };

  config = lib.mkIf hasEntries {
    sops.secrets = lib.genAttrs secretList (
      secretName:
      if lib.elem secretName pathSecrets then
        { restartUnits = [ "nginx.service" ]; }
      else
        { restartUnits = [ "xray-dynamic-subscriptions-sync.service" ]; }
    );

    sops.templates."xray-dynamic-subscriptions.conf" = {
      owner = "root";
      group = "nginx";
      mode = "0440";
      content = lib.concatMapStringsSep "\n" (
        name:
        let
          entry = cfg.entries.${name};
        in
        ''
          location = ${config.sops.placeholder.${entry.pathSecret}} {
            alias /var/lib/xray-dynamic-subscriptions/${name}.txt;
            default_type text/plain;
            add_header Cache-Control "private, no-store";
            access_log off;
          }
        ''
      ) entryNames;
    };

    services.nginx.virtualHosts.${cfg.hostName}.extraConfig = lib.mkAfter ''
      include ${config.sops.templates."xray-dynamic-subscriptions.conf".path};
    '';

    systemd.services.xray-dynamic-subscriptions-sync = {
      description = "Sync preferred IPs and render dynamic Xray subscriptions";
      after = [
        "network-online.target"
        "sops-install-secrets.service"
      ];
      wants = [ "network-online.target" ];
      before = [ "nginx.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "xray-dynamic-subscriptions";
        StateDirectoryMode = "0750";
        Group = "nginx";
        ExecStart = "${pkgs.python3}/bin/python3 ${syncScript} ${manifestFile}";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/xray-dynamic-subscriptions" ];
      };
    };

    systemd.timers.xray-dynamic-subscriptions-sync = {
      description = "Periodically refresh dynamic Xray preferred IP subscriptions";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "30m";
        Persistent = true;
      };
    };
  };
}
