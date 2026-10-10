#!/bin/sh
# ---
# Module: Router CloudflareST origin-aware updater
# Description: Tests Cloudflare ingress IPs against each regional CDN origin and uploads separate signed pools.
# Scope: Script
# ---
# Notes:
# - Secrets belong in /root/cfst/edge.env (mode 0600), never in this repository.
# - The test URL must bypass CDN cache so each measurement reaches the matching origin.
set -eu

WORKDIR="/root/cfst"
CONFIG_FILE="${CFST_CONFIG_FILE:-${WORKDIR}/edge.env}"
CFST_BIN="${CFST_BIN:-${WORKDIR}/CloudflareST_proxy_linux_arm64}"
RUN_DIR_BASE="${CFST_RUN_DIR_BASE:-/tmp/cfst-direct}"

usage() {
  echo "usage: $0 [--pool la|sg] [--upload-only]" >&2
  exit 64
}

[ -r "$CONFIG_FILE" ] || {
  echo "missing $CONFIG_FILE" >&2
  exit 1
}
# shellcheck disable=SC1090
. "$CONFIG_FILE"

: "${EDGE_UPDATE_BASE:?EDGE_UPDATE_BASE is required}"
: "${IP_UPDATE_KEY:?IP_UPDATE_KEY is required}"
: "${CFST_SPEEDTEST_PATH:?CFST_SPEEDTEST_PATH is required}"

case "$EDGE_UPDATE_BASE" in https://*) ;; *) echo "EDGE_UPDATE_BASE must be an HTTPS URL" >&2; exit 1 ;; esac
case "$CFST_SPEEDTEST_PATH" in /*) ;; *) echo "CFST_SPEEDTEST_PATH must begin with /" >&2; exit 1 ;; esac

selected_pool=""
upload_only=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --pool) [ "$#" -ge 2 ] || usage; selected_pool="$2"; shift 2 ;;
    --upload-only) upload_only=1; shift ;;
    *) usage ;;
  esac
done
case "$selected_pool" in ""|la|sg) ;; *) usage ;; esac

pool_host() {
  case "$1" in la) printf '%s\n' 'la-cdn.bdot.in' ;; sg) printf '%s\n' 'sg-cdn.bdot.in' ;; *) return 1 ;; esac
}
pool_label() {
  case "$1" in la) printf '%s\n' 'LA-CF' ;; sg) printf '%s\n' 'SG-CF' ;; esac
}
resolve_edge_ip() {
  edge_host="${EDGE_UPDATE_BASE#https://}"
  edge_host="${edge_host%%/*}"
  nslookup "$edge_host" "${CFST_DNS_SERVER:-1.1.1.1}" 2>/dev/null |
    sed -n '/^Name:/,$ { /^Address: [0-9][0-9.]*$/ { s/^Address: //; p; q; } }'
}

upload_pool() {
  pool="$1"
  input_file="$2"
  [ -s "$input_file" ] || return 1
  timestamp="$(date +%s)"
  signature="$( (printf '%s\n' "$timestamp"; cat "$input_file") | openssl dgst -sha256 -hmac "$IP_UPDATE_KEY" -hex | awk '{print $NF}')"
  edge_host="${EDGE_UPDATE_BASE#https://}"
  edge_host="${edge_host%%/*}"
  edge_ip="$(resolve_edge_ip)"
  [ -n "$edge_ip" ] || {
    logger -t cfst "cannot resolve the preferred-pool Worker endpoint"
    return 1
  }
  curl --fail-with-body --silent --show-error \
    --resolve "$edge_host:443:$edge_ip" \
    --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 30 \
    -H "X-Edge-Timestamp: $timestamp" \
    -H "X-Edge-Signature: $signature" \
    -H "Content-Type: text/plain" \
    --data-binary "@$input_file" \
    "${EDGE_UPDATE_BASE}/admin/preferred-ips/${pool}" >/dev/null
}

run_pool() {
  pool="$1"
  host="$(pool_host "$pool")"
  label="$(pool_label "$pool")"
  result_file="$WORKDIR/result-${pool}.csv"
  ip_file="$WORKDIR/new-ips-${pool}.txt"
  run_dir="$RUN_DIR_BASE/$pool"
  mkdir -p "$run_dir"
  chmod 755 "$run_dir"

  if [ "$upload_only" -eq 1 ]; then
    upload_pool "$pool" "$ip_file"
    logger -t cfst "uploaded existing ${pool} preferred endpoint pool"
    return 0
  fi
  [ -x "$CFST_BIN" ] || {
    logger -t cfst "CloudflareST binary not found at $CFST_BIN"
    return 1
  }
  cp "$CFST_BIN" "$run_dir/cfst"
  seed_source="${CFST_SEED_FILE:-$ip_file}"
  if [ -s "$seed_source" ]; then
    sed 's/:443.*//' "$seed_source" > "$run_dir/ip.txt"
  else
    cp "$WORKDIR/ip.txt" "$run_dir/ip.txt"
  fi
  chmod 755 "$run_dir/cfst"
  chmod 644 "$run_dir/ip.txt"

  result_tmp="$(mktemp /tmp/cfst-${pool}-result.csv.XXXXXX)"
  ip_tmp="$(mktemp "$WORKDIR/new-ips-${pool}.txt.XXXXXX")"
  log_tmp="$(mktemp /tmp/cfst-${pool}-run.XXXXXX)"
  pid_tmp="$(mktemp /tmp/cfst-${pool}-pid.XXXXXX)"
  rm -f "$pid_tmp"
  chown nobody:nogroup "$result_tmp" "$log_tmp"
  cfst_pid=""
  cleanup() {
    [ -z "$cfst_pid" ] || kill "$cfst_pid" 2>/dev/null || true
    rm -f "$result_tmp" "$ip_tmp" "$log_tmp" "$pid_tmp"
  }
  trap cleanup EXIT INT TERM

  /sbin/start-stop-daemon -S -b -m -p "$pid_tmp" \
    -c nobody:nogroup -d "$run_dir" -O "$log_tmp" -x "$run_dir/cfst" -- \
    -o "$result_tmp" \
    -n "${CFST_LATENCY_THREADS:-8}" \
    -t "${CFST_ATTEMPTS:-1}" \
    -sl "${CFST_MIN_SPEED:-2}" \
    -dn "${CFST_DOWNLOADS:-8}" \
    -dt "${CFST_DURATION:-4}" \
    -f "$run_dir/ip.txt" \
    -url "https://${host}${CFST_SPEEDTEST_PATH}" -p 0
  cfst_pid="$(cat "$pid_tmp")"
  deadline=$(( $(date +%s) + ${CFST_MAX_RUNTIME:-600} ))
  while kill -0 "$cfst_pid" 2>/dev/null; do
    sleep 1
    if [ "$(date +%s)" -ge "$deadline" ]; then
      logger -t cfst "${pool} CloudflareST run exceeded its runtime budget"
      kill "$cfst_pid" 2>/dev/null || true
      wait "$cfst_pid" 2>/dev/null || true
      exit 1
    fi
  done
  wait "$cfst_pid" || true
  cfst_pid=""

  [ -s "$result_tmp" ] || {
    logger -t cfst "${pool} CloudflareST produced no result"
    tail -c 1200 "$log_tmp" >&2 || true
    exit 1
  }
  awk -F',' -v label="$label" 'NR>1 && $1 ~ /^[0-9a-fA-F:.]+$/ { printf "%s:443#%s-%02d-%.2fMB/s\\n", $1, label, NR - 1, $6 }' "$result_tmp" | head -n "${CFST_RESULTS:-8}" > "$ip_tmp"
  result_count="$(wc -l < "$ip_tmp")"
  [ "$result_count" -ge "${CFST_MIN_RESULTS:-4}" ] || {
    logger -t cfst "${pool} pool has only $result_count usable endpoints; preserving last known-good list"
    exit 1
  }
  upload_pool "$pool" "$ip_tmp"
  mv "$result_tmp" "$result_file"; result_tmp=""
  mv "$ip_tmp" "$ip_file"; ip_tmp=""
  logger -t cfst "updated ${pool} preferred endpoint pool with $result_count entries"
}

if [ -n "$selected_pool" ]; then
  run_pool "$selected_pool"
else
  run_pool la
  run_pool sg
fi
