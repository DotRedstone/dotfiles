# ---
# Module: GCP Egress Guard
# Description: Fail-closed monthly egress cap for traffic-heavy services on Google Cloud
# Scope: System
# Notes:
# - This is a local safety brake, not a replacement for a Google Cloud billing budget.
# - A vnStat read failure stops guarded services until accounting recovers.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.gcpEgressGuard;

  guard = pkgs.writeShellApplication {
    name = "gcp-egress-guard";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
      pkgs.vnstat
    ];
    text = ''
      set -euo pipefail

      interface=${lib.escapeShellArg cfg.interface}
      limit_bytes=${toString cfg.limitBytes}
      state_file=/var/lib/gcp-egress-guard/state
      units=(${lib.concatMapStringsSep " " lib.escapeShellArg cfg.guardedUnits})

      current_month() {
        date +%Y-%m
      }

      stop_guarded_units() {
        systemctl stop -- "''${units[@]}" || true
      }

      start_guarded_units() {
        systemctl start -- "''${units[@]}" || true
      }

      read_tx_bytes() {
        local usage_json year month
        year=$(date +%Y)
        month=$(date +%-m)
        usage_json=$(vnstat --iface "$interface" --json m 1)
        jq -er \
          --arg interface "$interface" \
          --argjson year "$year" \
          --argjson month "$month" \
          '[.interfaces[]? | select(.name == $interface) | .traffic.month[]? | select(.date.year == $year and .date.month == $month) | .tx] | add // 0' \
          <<<"$usage_json"
      }

      check_usage() {
        local month tx_bytes previous=""
        month=$(current_month)
        if ! tx_bytes=$(read_tx_bytes); then
          printf 'fault:%s\n' "$month" > "$state_file"
          stop_guarded_units
          echo "vnStat accounting failed; guarded services were stopped" >&2
          return 1
        fi

        if [[ -f "$state_file" ]]; then
          previous=$(<"$state_file")
        fi

        if (( tx_bytes >= limit_bytes )); then
          printf 'limit:%s\n' "$month" > "$state_file"
          stop_guarded_units
          echo "monthly TX limit reached: $tx_bytes/$limit_bytes bytes"
          return 0
        fi

        if [[ "$previous" == "limit:$month" ]]; then
          stop_guarded_units
          echo "monthly TX limit remains latched: $tx_bytes/$limit_bytes bytes"
          return 0
        fi

        if [[ -n "$previous" ]]; then
          rm -f -- "$state_file"
          start_guarded_units
        fi

        echo "monthly TX below limit: $tx_bytes/$limit_bytes bytes"
      }

      show_status() {
        local tx_bytes state="clear"
        if [[ -f "$state_file" ]]; then
          state=$(<"$state_file")
        fi
        if tx_bytes=$(read_tx_bytes); then
          printf 'interface=%s tx_bytes=%s limit_bytes=%s state=%s\n' \
            "$interface" "$tx_bytes" "$limit_bytes" "$state"
        else
          printf 'interface=%s tx_bytes=unavailable limit_bytes=%s state=%s\n' \
            "$interface" "$limit_bytes" "$state"
          return 1
        fi
      }

      case "''${1:-check}" in
        check) check_usage ;;
        status) show_status ;;
        *) echo "usage: gcp-egress-guard [check|status]" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  options.dot.services.gcpEgressGuard = {
    enable = lib.mkEnableOption "a fail-closed Google Cloud monthly egress guard";

    interface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
      description = "WAN interface tracked by vnStat.";
    };

    limitBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 180000000000;
      description = "Monthly transmitted-byte threshold before guarded services are stopped.";
    };

    guardedUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "xray.service" ];
      description = "Services stopped after the threshold or an accounting failure.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.vnstat.enable = true;
    environment.systemPackages = [ guard ];

    systemd.services.gcp-egress-guard = {
      description = "Google Cloud monthly egress safety brake";
      after = [
        "network-online.target"
        "vnstat.service"
      ];
      wants = [ "network-online.target" ];
      requires = [ "vnstat.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${guard}/bin/gcp-egress-guard check";
        StateDirectory = "gcp-egress-guard";
        StateDirectoryMode = "0755";
        UMask = "0022";
      };
    };

    systemd.timers.gcp-egress-guard = {
      description = "Periodically enforce the Google Cloud monthly egress cap";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = "5m";
        Persistent = true;
        RandomizedDelaySec = "30s";
        Unit = "gcp-egress-guard.service";
      };
    };
  };
}
