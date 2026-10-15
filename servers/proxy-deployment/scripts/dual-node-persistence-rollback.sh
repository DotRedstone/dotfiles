#!/bin/sh
set -eu

# 一次性持久切换保护：仅接受预定的两台主机与精确闭包。
IFS= read -r node < /proc/sys/kernel/hostname
case "$node" in
  conduit)
    old_profile=/nix/store/92j5wm1b6jzjkv8rrx7xj9nahggqkglm-nixos-system-conduit-26.11.20260831.34ab990
    old_boot=/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990
    candidate=/nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990
    subscription_host=la-node.540123.xyz
    subscription_names='websocket reality cdn'
    service_names='sshd nginx xray xray-subscriptions-check'
    ;;
  hopper)
    old_profile=/nix/store/w0aqhcla0ip3vp4mcwf6i8nvpdih575v-nixos-system-hopper-26.11.20260831.34ab990
    old_boot=/nix/store/k69xg4y5d9qvp7w37p98q6vbfl0i1kgn-nixos-system-hopper-26.11.20260831.34ab990
    candidate=/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990
    subscription_host=sg-node.540123.xyz
    subscription_names='hysteria2 websocket reality cdn guest'
    service_names='sshd nginx xray xray-subscriptions-check gmail-archiver'
    ;;
  *)
    echo 'persistence rollback refused: unexpected hostname' >&2
    exit 1
    ;;
esac

marker=/run/stage1-persistence-rollback.marker
profile=/nix/var/nix/profiles/system
readlink="$old_profile/sw/bin/readlink"
systemctl="$old_profile/sw/bin/systemctl"
nix_env="$old_profile/sw/bin/nix-env"
cmp="$old_profile/sw/bin/cmp"
grep="$old_profile/sw/bin/grep"
curl="$old_profile/sw/bin/curl"
cat="$old_profile/sw/bin/cat"
rm="$old_profile/sw/bin/rm"
awk="$old_profile/sw/bin/awk"

current=$("$readlink" -f /run/current-system)
installed=$("$readlink" -f "$profile")
booted=$("$readlink" -f /run/booted-system)

if [ ! -e "$marker" ]; then
  if [ "$current" = "$candidate" ] && [ "$installed" = "$old_profile" ] &&
     [ "$booted" = "$old_boot" ]; then
    echo 'persistence rollback rehearsal: no-op branch executed'
    exit 0
  fi
  echo 'persistence rollback refused: marker absent or baseline changed' >&2
  exit 1
fi

if [ "$booted" != "$old_boot" ]; then
  echo 'persistence rollback refused: booted system changed' >&2
  exit 1
fi

switch_status=0
if [ ! -x "$old_profile/bin/switch-to-configuration" ]; then
  echo 'persistence rollback refused: old switch script missing' >&2
  exit 1
fi
if [ "$current" = "$candidate" ] && [ "$installed" = "$candidate" ]; then
  "$nix_env" -p "$profile" --set "$old_profile"
  "$old_profile/bin/switch-to-configuration" switch || switch_status=$?
elif [ "$current" = "$candidate" ] && [ "$installed" = "$old_profile" ]; then
  "$old_profile/bin/switch-to-configuration" switch || switch_status=$?
elif [ "$current" = "$old_profile" ] && [ "$installed" = "$old_profile" ]; then
  "$old_profile/bin/switch-to-configuration" switch || switch_status=$?
elif [ "$current" != "$old_profile" ] || [ "$installed" != "$old_profile" ]; then
  echo 'persistence rollback refused: unexpected current system or profile' >&2
  exit 1
fi

if [ "$("$readlink" -f /run/current-system)" != "$old_profile" ] ||
   [ "$("$readlink" -f "$profile")" != "$old_profile" ]; then
  echo 'persistence rollback failed: old runtime/profile not restored' >&2
  exit 1
fi
case "$node" in
  conduit)
    "$awk" '/^menuentry "NixOS"/{inside=1} /^submenu "NixOS/{inside=0} inside && /init=/{print; exit}' \
      /boot/grub/grub.cfg | "$grep" -Fq "init=$old_profile/init"
    ;;
  hopper)
    # awk 字段表达式必须保持字面量。
    # shellcheck disable=SC2016
    entry=$("$awk" '$1 == "default" { print $2; exit }' /boot/loader/loader.conf)
    case "$entry" in
      ''|*/*|*..*)
        echo 'persistence rollback failed: invalid default boot entry' >&2
        exit 1
        ;;
    esac
    "$grep" -Fq "init=$old_profile/init" "/boot/loader/entries/$entry"
    ;;
esac

rendered=/run/secrets/rendered/xray-node.json
credential=/run/credentials/xray.service/config.json
if ! "$cmp" -s "$rendered" "$credential"; then
  "$systemctl" restart xray.service
fi
"$cmp" -s "$rendered" "$credential"
for unit in $service_names; do
  "$systemctl" is-active --quiet "$unit.service"
done
"$grep" -q '"email"[[:space:]]*:[[:space:]]*"managed:guest"' "$credential"
"$grep" -q '"email"[[:space:]]*:[[:space:]]*"managed:canary"' "$credential"
if "$grep" -q '"email"[[:space:]]*:[[:space:]]*"managed:rotation"' "$credential"; then
  echo 'persistence rollback failed: rotation identity remains loaded' >&2
  exit 1
fi
if "$systemctl" is-active --quiet proxy-origin-proof.service; then
  echo 'persistence rollback failed: new proof service remains active' >&2
  exit 1
fi
for name in $subscription_names; do
  path=$("$cat" "/run/secrets/xray/subscription_${name}_path")
  "$curl" --noproxy '*' --connect-timeout 5 --max-time 10 \
    --resolve "$subscription_host:80:127.0.0.1" \
    -fsS "http://$subscription_host$path" |
    "$cmp" -s - "/run/secrets/xray/subscription_${name}_content"
done
if [ "$switch_status" -ne 0 ]; then
  echo 'persistence rollback restored old state but switch reported failure' >&2
  exit "$switch_status"
fi

"$rm" -f -- "$marker"
echo 'persistence rollback verified: old runtime, profile, and services restored'
