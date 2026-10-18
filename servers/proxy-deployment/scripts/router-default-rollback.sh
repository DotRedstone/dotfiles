#!/bin/sh
# 由路由器 crond 每分钟调用；仅在 root-only marker 到期后恢复旧 OpenClash 源配置。
set -eu

state=${1:-/root/proxy-v2-cutover/rollback.env}
marker=/root/proxy-v2-cutover/armed
uci=/sbin/uci
sha256sum=/usr/bin/sha256sum
date=/bin/date
cp=/bin/cp
rm=/bin/rm
pidof=/bin/pidof
logger=/usr/bin/logger

[ -e "$marker" ] || exit 0
if [ ! -r "$state" ] || [ "$(/bin/stat -c '%u %a' "$state")" != '0 600' ]; then
  "$logger" -t proxy-v2-rollback 'refused: state file missing or permissions invalid'
  exit 1
fi
# shellcheck source=/dev/null
. "$state"

case "${OLD_SOURCE:-}" in /etc/openclash/config/*.yaml) ;; *) exit 1 ;; esac
case "${NEW_SOURCE:-}" in /etc/openclash/config/*.yaml) ;; *) exit 1 ;; esac
[ "$OLD_SOURCE" != "$NEW_SOURCE" ] || exit 1
case "${DEADLINE_EPOCH:-}" in *[!0-9]*|'') exit 1 ;; esac
case "${OLD_SHA256:-}" in *[!0-9a-f]*|'') exit 1 ;; esac
[ "${#OLD_SHA256}" -eq 64 ] || exit 1
[ -f "${OLD_BACKUP:-}" ] || exit 1
[ "$($sha256sum "$OLD_BACKUP" | /usr/bin/cut -d ' ' -f 1)" = "$OLD_SHA256" ] || exit 1

[ "$($date +%s)" -ge "$DEADLINE_EPOCH" ] || exit 0
current=$($uci -q get openclash.config.config_path || true)
if [ "$current" != "$OLD_SOURCE" ] && [ "$current" != "$NEW_SOURCE" ]; then
  "$logger" -t proxy-v2-rollback 'refused: unexpected active source'
  exit 1
fi

if [ ! -f "$OLD_SOURCE" ] ||
   [ "$($sha256sum "$OLD_SOURCE" | /usr/bin/cut -d ' ' -f 1)" != "$OLD_SHA256" ]; then
  "$cp" -p "$OLD_BACKUP" "$OLD_SOURCE"
fi
$uci -q set "openclash.config.config_path=$OLD_SOURCE"
$uci -q commit openclash
/etc/init.d/openclash restart >/dev/null 2>&1 || true

[ "$($uci -q get openclash.config.config_path)" = "$OLD_SOURCE" ] || exit 1
[ "$($sha256sum "$OLD_SOURCE" | /usr/bin/cut -d ' ' -f 1)" = "$OLD_SHA256" ] || exit 1
core_pid=$($pidof clash | /usr/bin/awk '{print $1}')
[ -n "$core_pid" ] || exit 1
/usr/bin/tr '\000' ' ' < "/proc/$core_pid/cmdline" |
  /bin/grep -Fq '/etc/openclash/config.yaml' || exit 1
$pidof dnsmasq >/dev/null || exit 1

$rm -f "$marker"
"$logger" -t proxy-v2-rollback 'old OpenClash source and core restored'
