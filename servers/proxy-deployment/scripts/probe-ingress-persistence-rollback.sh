#!/bin/sh
set -eu

# 仅回退 probe ingress；rotation 已是持久基线，不得使用旧阶段的回退脚本。
IFS= read -r node < /proc/sys/kernel/hostname
case "$node" in
  conduit)
    rotation=/nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990
    probe=/nix/store/73qxjfv9l6fjp73fvqpi31a02gnnvwd4-nixos-system-conduit-26.11.20260831.34ab990
    booted=/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990
    subscription_host=la-node.540123.xyz
    subscription_names='websocket reality cdn'
    service_names='sshd nginx xray proxy-origin-proof xray-subscriptions-check'
    ;;
  hopper)
    rotation=/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990
    probe=/nix/store/irwzjkl39v1ra9la699smvymkxpbgzz8-nixos-system-hopper-26.11.20260831.34ab990
    booted=/nix/store/k69xg4y5d9qvp7w37p98q6vbfl0i1kgn-nixos-system-hopper-26.11.20260831.34ab990
    subscription_host=sg-node.540123.xyz
    subscription_names='hysteria2 websocket reality cdn guest'
    service_names='sshd nginx xray proxy-origin-proof xray-subscriptions-check gmail-archiver'
    ;;
  *) echo 'probe persistence rollback refused: unexpected hostname' >&2; exit 1 ;;
esac

marker=/run/stage1-probe-persistence-rollback.marker
timer=stage1-probe-persistence-rollback.timer
script=/run/stage1-probe-persistence-rollback.sh
profile=/nix/var/nix/profiles/system
readlink="$rotation/sw/bin/readlink"
systemctl="$rotation/sw/bin/systemctl"
nix_env="$rotation/sw/bin/nix-env"
awk="$rotation/sw/bin/awk"
grep="$rotation/sw/bin/grep"
cmp="$rotation/sw/bin/cmp"
cat="$rotation/sw/bin/cat"
curl="$rotation/sw/bin/curl"

default_system() {
  case "$node" in
    conduit)
      "$awk" '/^menuentry "NixOS"/{inside=1} /^submenu "NixOS/{inside=0} inside && /init=/{print; exit}' \
        /boot/grub/grub.cfg | "$grep" -F -e "init=$rotation/init" -e "init=$probe/init"
      ;;
    hopper)
      # shellcheck disable=SC2016
      entry=$("$awk" '$1 == "default" { print $2; exit }' /boot/loader/loader.conf)
      case "$entry" in ''|*/*|*..*) return 1 ;; esac
      "$grep" -F -e "init=$rotation/init" -e "init=$probe/init" "/boot/loader/entries/$entry"
      ;;
  esac
}

current=$("$readlink" -f /run/current-system)
installed=$("$readlink" -f "$profile")
booted_now=$("$readlink" -f /run/booted-system)
if [ "$booted_now" != "$booted" ]; then
  echo 'probe persistence rollback refused: booted system changed' >&2
  exit 1
fi
case "$current:$installed" in
  "$rotation:$rotation"|"$probe:$rotation"|"$probe:$probe"|"$rotation:$probe") ;;
  *) echo 'probe persistence rollback refused: unexpected current system or profile' >&2; exit 1 ;;
esac
default_line=$(default_system)
case "$default_line" in
  *"init=$rotation/init"*|*"init=$probe/init"*) ;;
  *) echo 'probe persistence rollback refused: unexpected default boot entry' >&2; exit 1 ;;
esac

timer_state=$("$systemctl" show "$timer" -p ActiveState --value)
if [ "$timer_state" = active ]; then
  "$systemctl" show stage1-probe-persistence-rollback.service -p ExecStart --value |
    "$grep" -Fq "$script"
elif [ "$timer_state" != inactive ]; then
  echo 'probe persistence rollback refused: unexpected timer state' >&2
  exit 1
fi
if [ ! -e "$marker" ]; then
  if [ "$current" = "$probe" ] && [ "$installed" = "$rotation" ] &&
     [ "${default_line#*init="$rotation"/init}" != "$default_line" ] &&
     [ "$timer_state" = inactive ]; then
    echo 'probe persistence rollback rehearsal: no-op branch executed'
    exit 0
  fi
  echo 'probe persistence rollback refused: marker absent or baseline changed' >&2
  exit 1
fi

if [ ! -x "$rotation/bin/switch-to-configuration" ]; then
  echo 'probe persistence rollback refused: rotation switch script missing' >&2
  exit 1
fi
if [ "$installed" = "$probe" ]; then
  "$nix_env" -p "$profile" --set "$rotation"
fi
switch_status=0
"$rotation/bin/switch-to-configuration" switch || switch_status=$?
if [ "$("$readlink" -f /run/current-system)" != "$rotation" ] ||
   [ "$("$readlink" -f "$profile")" != "$rotation" ] ||
   [ "$("$readlink" -f /run/booted-system)" != "$booted" ]; then
  echo 'probe persistence rollback failed: rotation runtime/profile or booted system differs' >&2
  exit 1
fi
default_line=$(default_system)
case "$default_line" in
  *"init=$rotation/init"*) ;;
  *) echo 'probe persistence rollback failed: default boot entry differs' >&2; exit 1 ;;
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
if "$systemctl" is-active --quiet proxy-preferred-probe.service; then
  echo 'probe persistence rollback failed: probe service remains active' >&2
  exit 1
fi
"$grep" -q '"email"[[:space:]]*:[[:space:]]*"managed:rotation"' "$credential"
"$grep" -q '"email"[[:space:]]*:[[:space:]]*"managed:canary"' "$credential"
if [ "$node" = hopper ]; then
  "$grep" -q '"email"[[:space:]]*:[[:space:]]*"managed:guest"' "$credential"
fi
for name in $subscription_names; do
  path=$("$cat" "/run/secrets/xray/subscription_${name}_path")
  "$curl" --noproxy '*' --connect-timeout 5 --max-time 10 \
    --resolve "$subscription_host:80:127.0.0.1" \
    -fsS "http://$subscription_host$path" |
    "$cmp" -s - "/run/secrets/xray/subscription_${name}_content"
done
if [ "$switch_status" -ne 0 ]; then
  echo 'probe persistence rollback restored checks but switch reported failure' >&2
  exit "$switch_status"
fi

# 保留 marker，待人工复核 SSH、Gmail API、proof、旧出口及订阅外部路径。
echo 'probe persistence rollback verified locally; marker retained for external acceptance'
