#!/bin/sh
set -eu

# 仅回退 Conduit 发布器激活；当前旧闭包已包含轮换后的 proof 凭据。
old=/nix/store/6aj3yk1wkgiw4cmyp8hkh7zjxzyd56ai-nixos-system-conduit-26.11.20260831.34ab990
candidate=/nix/store/lgacjf7m9jkz5cvaramf0dmcl3qbrcas-nixos-system-conduit-26.11.20260831.34ab990
booted=/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990
profile=/nix/var/nix/profiles/system
marker=/run/proxy-publisher-rollback.marker
timer=proxy-publisher-rollback.timer

if [ "$(id -u)" -ne 0 ] || [ "$(cat /proc/sys/kernel/hostname)" != conduit ] ||
   [ ! -x "$old/bin/switch-to-configuration" ] || [ ! -d "$candidate" ] ||
   [ "$(readlink -f /run/booted-system)" != "$booted" ]; then
  echo 'publisher rollback refused: host or store identity differs' >&2
  exit 1
fi
current=$(readlink -f /run/current-system)
installed=$(readlink -f "$profile")
case "$current:$installed" in
  "$old:$old"|"$candidate:$candidate"|"$candidate:$old") ;;
  *) echo 'publisher rollback refused: current system or profile differs' >&2; exit 1 ;;
esac

if [ ! -e "$marker" ]; then
  if [ "$current:$installed" = "$old:$old" ] &&
     [ "$(systemctl show "$timer" -p ActiveState --value)" = inactive ]; then
    echo 'publisher rollback rehearsal: baseline verified; no action'
    exit 0
  fi
  echo 'publisher rollback refused: marker absent' >&2
  exit 1
fi
if [ ! -f "$marker" ] || [ "$(stat -c '%u:%g:%a' "$marker")" != '0:0:600' ] ||
   [ "$(cat "$marker")" != "$old $candidate $booted" ]; then
  echo 'publisher rollback refused: marker differs' >&2
  exit 1
fi

if [ "$installed" = "$candidate" ]; then
  "$old/sw/bin/nix-env" -p "$profile" --set "$old"
fi
"$old/bin/switch-to-configuration" switch
if [ "$(readlink -f /run/current-system)" != "$old" ] ||
   [ "$(readlink -f "$profile")" != "$old" ] ||
   [ "$(readlink -f /run/booted-system)" != "$booted" ]; then
  echo 'publisher rollback failed: system identity differs' >&2
  exit 1
fi
for unit in sshd nginx xray proxy-origin-proof proxy-preferred-probe xray-subscriptions-check; do
  systemctl is-active --quiet "$unit.service"
done
echo 'publisher rollback verified locally; marker retained for inspection'
