#!/bin/sh
set -eu

old=/nix/store/dv9bxyww51y3mxv55vbvrsn8qhv6gnp1-nixos-system-hopper-26.11.20260831.34ab990
candidate=/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990
marker=/run/stage1-hopper-rotation-rollback.marker
readlink="$old/sw/bin/readlink"
systemctl="$old/sw/bin/systemctl"
cmp="$old/sw/bin/cmp"
grep="$old/sw/bin/grep"
rm="$old/sw/bin/rm"

current=$("$readlink" -f /run/current-system)
if [ ! -e "$marker" ]; then
  if [ "$current" = "$old" ]; then
    echo 'rollback rehearsal: no-op branch executed'
    exit 0
  fi
  echo 'rollback refused: marker absent and current system changed' >&2
  exit 1
fi

if [ "$current" = "$old" ]; then
  echo 'rollback deferred: candidate not active; marker retained' >&2
  exit 1
fi
if [ "$current" != "$candidate" ] || [ ! -x "$old/bin/switch-to-configuration" ]; then
  echo 'rollback refused: unexpected current system or missing old switch script' >&2
  exit 1
fi

switch_status=0
"$old/bin/switch-to-configuration" test || switch_status=$?
if [ "$("$readlink" -f /run/current-system)" != "$old" ]; then
  echo 'rollback failed: current system differs from old closure' >&2
  exit 1
fi

rendered=/run/secrets/rendered/xray-node.json
credential=/run/credentials/xray.service/config.json
if ! "$cmp" -s "$rendered" "$credential"; then
  "$systemctl" restart xray.service
fi
"$cmp" -s "$rendered" "$credential"
for unit in sshd.service nginx.service xray.service proxy-origin-proof.service gmail-archiver.service; do
  "$systemctl" is-active --quiet "$unit"
done
"$grep" -q '"email"[[:space:]]*:[[:space:]]*"managed:guest"' "$credential"
"$grep" -q '"email"[[:space:]]*:[[:space:]]*"managed:canary"' "$credential"
if "$grep" -q '"email"[[:space:]]*:[[:space:]]*"managed:rotation"' "$credential"; then
  echo 'rollback failed: rotation identity remains loaded' >&2
  exit 1
fi
if [ "$switch_status" -ne 0 ]; then
  echo 'rollback restored old closure but switch command reported failure' >&2
  exit "$switch_status"
fi

"$rm" -f -- "$marker"
echo 'rollback verified: old closure and Xray credential restored'
