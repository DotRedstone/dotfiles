#!/bin/sh
set -eu

# 公开测速入口阶段：旧闭包仍提供签名 /probe，不得回退至 rotation。
if [ "$#" -ne 1 ]; then
  echo 'optimizer probe rollback refused: expected test or switch mode' >&2
  exit 1
fi
mode=$1
case "$mode" in test|switch) ;; *) echo 'optimizer probe rollback refused: invalid mode' >&2; exit 1 ;; esac

IFS= read -r node < /proc/sys/kernel/hostname
case "$node" in
  conduit)
    old=/nix/store/73qxjfv9l6fjp73fvqpi31a02gnnvwd4-nixos-system-conduit-26.11.20260831.34ab990
    candidate=/nix/store/flnlzx6zqv3g2ai82yfyvxr47r6ml418-nixos-system-conduit-26.11.20260831.34ab990
    booted=/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990
    subscription_host=la-node.540123.xyz
    subscription_names='websocket reality cdn'
    service_names='sshd nginx xray proxy-origin-proof xray-subscriptions-check proxy-preferred-probe'
    ;;
  hopper)
    old=/nix/store/irwzjkl39v1ra9la699smvymkxpbgzz8-nixos-system-hopper-26.11.20260831.34ab990
    # 目标 ARM 主机原生构建的顶层 outPath；激活前仍须复核目标 store 与当前状态。
    candidate=/nix/store/89vwm78ydgckkv0jqw0sfdgg08hg2ggw-nixos-system-hopper-26.11.20260831.34ab990
    booted=/nix/store/k69xg4y5d9qvp7w37p98q6vbfl0i1kgn-nixos-system-hopper-26.11.20260831.34ab990
    subscription_host=sg-node.540123.xyz
    subscription_names='hysteria2 websocket reality cdn guest'
    service_names='sshd nginx xray proxy-origin-proof xray-subscriptions-check proxy-preferred-probe gmail-archiver'
    ;;
  *) echo 'optimizer probe rollback refused: unexpected hostname' >&2; exit 1 ;;
esac
case "$candidate" in
  /nix/store/*-nixos-system-"$node"-*) ;;
  *) echo 'optimizer probe rollback refused: candidate not verified' >&2; exit 1 ;;
esac

marker=/run/stage1-optimizer-probe-rollback.marker
timer=stage1-optimizer-probe-rollback.timer
script=/run/stage1-optimizer-probe-rollback.sh
profile=/nix/var/nix/profiles/system
readlink="$old/sw/bin/readlink"
systemctl="$old/sw/bin/systemctl"
nix_env="$old/sw/bin/nix-env"
awk="$old/sw/bin/awk"
grep="$old/sw/bin/grep"
cmp="$old/sw/bin/cmp"
cat="$old/sw/bin/cat"
curl="$old/sw/bin/curl"
stat="$old/sw/bin/stat"
id="$old/sw/bin/id"

default_system() {
  case "$node" in
    conduit)
      "$awk" '/^menuentry "NixOS"/{inside=1} /^submenu "NixOS/{inside=0} inside && /init=/{print; exit}' \
        /boot/grub/grub.cfg | "$grep" -F -e "init=$old/init" -e "init=$candidate/init"
      ;;
    hopper)
      # shellcheck disable=SC2016
      entry=$("$awk" '$1 == "default" { print $2; exit }' /boot/loader/loader.conf)
      case "$entry" in ''|*/*|*..*) return 1 ;; esac
      "$grep" -F -e "init=$old/init" -e "init=$candidate/init" "/boot/loader/entries/$entry"
      ;;
  esac
}

if [ "$("$id" -u)" -ne 0 ] || [ ! -x "$old/bin/switch-to-configuration" ] ||
   [ ! -d "$candidate" ]; then
  echo 'optimizer probe rollback refused: root or exact store paths unavailable' >&2
  exit 1
fi
current=$("$readlink" -f /run/current-system)
installed=$("$readlink" -f "$profile")
booted_now=$("$readlink" -f /run/booted-system)
if [ "$booted_now" != "$booted" ]; then
  echo 'optimizer probe rollback refused: booted system changed' >&2
  exit 1
fi
case "$current" in "$old"|"$candidate") ;; *) echo 'optimizer probe rollback refused: unexpected current system' >&2; exit 1 ;; esac
case "$installed" in "$old"|"$candidate") ;; *) echo 'optimizer probe rollback refused: unexpected profile' >&2; exit 1 ;; esac
default_line=$(default_system)
case "$default_line" in
  *"init=$old/init"*) default_path=$old ;;
  *"init=$candidate/init"*) default_path=$candidate ;;
  *) echo 'optimizer probe rollback refused: unexpected default boot entry' >&2; exit 1 ;;
esac
if [ "$mode" = test ] && { [ "$installed" != "$old" ] || [ "$default_path" != "$old" ]; }; then
  echo 'optimizer probe rollback refused: test requires old profile and default boot entry' >&2
  exit 1
fi

timer_state=$("$systemctl" show "$timer" -p ActiveState --value)
if [ "$timer_state" = active ]; then
  "$systemctl" show stage1-optimizer-probe-rollback.service -p ExecStart --value |
    "$grep" -Fq "$script $mode"
elif [ "$timer_state" != inactive ]; then
  echo 'optimizer probe rollback refused: unexpected timer state' >&2
  exit 1
fi
if [ ! -e "$marker" ]; then
  if [ "$current" = "$old" ] && [ "$installed" = "$old" ] &&
     [ "$default_path" = "$old" ] && [ "$timer_state" = inactive ]; then
    echo 'optimizer probe rollback rehearsal: no-op branch executed'
    exit 0
  fi
  echo 'optimizer probe rollback refused: marker absent or baseline changed' >&2
  exit 1
fi
expected_marker="$node $mode $old $candidate $booted"
if [ ! -f "$marker" ] || [ "$("$stat" -c '%u:%g:%a' "$marker")" != '0:0:600' ] ||
   [ "$("$cat" "$marker")" != "$expected_marker" ]; then
  echo 'optimizer probe rollback refused: marker identity or permissions differ' >&2
  exit 1
fi

if [ "$mode" = switch ] && [ "$installed" = "$candidate" ]; then
  "$nix_env" -p "$profile" --set "$old"
fi
switch_status=0
"$old/bin/switch-to-configuration" "$mode" || switch_status=$?
if [ "$("$readlink" -f /run/current-system)" != "$old" ] ||
   [ "$("$readlink" -f "$profile")" != "$old" ] ||
   [ "$("$readlink" -f /run/booted-system)" != "$booted" ]; then
  echo 'optimizer probe rollback failed: runtime, profile or booted system differs' >&2
  exit 1
fi
default_line=$(default_system)
case "$default_line" in
  *"init=$old/init"*) ;;
  *) echo 'optimizer probe rollback failed: default boot entry differs' >&2; exit 1 ;;
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
  echo 'optimizer probe rollback restored checks but switch reported failure' >&2
  exit "$switch_status"
fi

# 保留 marker 与 timer，待人工复核 SSH 双路径、签名 /probe、旧出口及外部订阅。
echo 'optimizer probe rollback verified locally; marker and timer retained for external acceptance'
