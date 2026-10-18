#!/bin/sh
set -eu

# 仅保护公开探针与 proof 凭据的持久切换；紧急回退后停用持有旧凭据的隔离服务。
IFS= read -r node < /proc/sys/kernel/hostname
case "$node" in
  conduit)
    baseline=/nix/store/73qxjfv9l6fjp73fvqpi31a02gnnvwd4-nixos-system-conduit-26.11.20260831.34ab990
    temporary=/nix/store/flnlzx6zqv3g2ai82yfyvxr47r6ml418-nixos-system-conduit-26.11.20260831.34ab990
    candidate=/nix/store/6aj3yk1wkgiw4cmyp8hkh7zjxzyd56ai-nixos-system-conduit-26.11.20260831.34ab990
    booted=/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990
    ;;
  hopper)
    baseline=/nix/store/irwzjkl39v1ra9la699smvymkxpbgzz8-nixos-system-hopper-26.11.20260831.34ab990
    temporary=/nix/store/89vwm78ydgckkv0jqw0sfdgg08hg2ggw-nixos-system-hopper-26.11.20260831.34ab990
    candidate=/nix/store/x19gwa1s1jkpn95332kp38fhj04myf3l-nixos-system-hopper-26.11.20260831.34ab990
    booted=/nix/store/k69xg4y5d9qvp7w37p98q6vbfl0i1kgn-nixos-system-hopper-26.11.20260831.34ab990
    ;;
  *) echo 'rollback refused: unexpected host' >&2; exit 1 ;;
esac

marker=/run/stage1-probe-rotation-rollback.marker
timer=stage1-probe-rotation-rollback.timer
script=/run/stage1-probe-rotation-rollback.sh
profile=/nix/var/nix/profiles/system
readlink="$baseline/sw/bin/readlink"
systemctl="$baseline/sw/bin/systemctl"
nix_env="$baseline/sw/bin/nix-env"

if [ "$(id -u)" -ne 0 ] || [ ! -x "$baseline/bin/switch-to-configuration" ] ||
   [ ! -d "$candidate" ] || [ "$("$readlink" -f /run/booted-system)" != "$booted" ]; then
  echo 'rollback refused: identity, store path or booted system differs' >&2
  exit 1
fi
current=$("$readlink" -f /run/current-system)
installed=$("$readlink" -f "$profile")
case "$current" in "$temporary"|"$candidate"|"$baseline") ;; *) echo 'rollback refused: current system differs' >&2; exit 1 ;; esac
case "$installed" in "$baseline"|"$candidate") ;; *) echo 'rollback refused: profile differs' >&2; exit 1 ;; esac
timer_state=$("$systemctl" show "$timer" -p ActiveState --value)
if [ ! -e "$marker" ]; then
  if [ "$current" = "$temporary" ] && [ "$installed" = "$baseline" ] &&
     [ "$timer_state" = inactive ]; then
    echo 'rollback rehearsal: baseline verified; no action'
    exit 0
  fi
  echo 'rollback refused: marker absent or baseline differs' >&2
  exit 1
fi
if [ ! -f "$marker" ] || [ "$(stat -c '%u:%g:%a' "$marker")" != '0:0:600' ] ||
   [ "$(cat "$marker")" != "$node $baseline $temporary $candidate $booted" ] ||
   [ "$timer_state" != active ] ||
   ! "$systemctl" show stage1-probe-rotation-rollback.service -p ExecStart --value |
     grep -Fq "$script"; then
  echo 'rollback refused: marker or timer differs' >&2
  exit 1
fi

if [ "$installed" = "$candidate" ]; then
  "$nix_env" -p "$profile" --set "$baseline"
fi
"$baseline/bin/switch-to-configuration" switch
# 旧 profile 含已轮换的 proof 凭据；紧急回退只保留旧代理与 SSH。
"$systemctl" stop proxy-preferred-probe.service proxy-origin-proof.service
if [ "$("$readlink" -f /run/current-system)" != "$baseline" ] ||
   [ "$("$readlink" -f "$profile")" != "$baseline" ] ||
   [ "$("$readlink" -f /run/booted-system)" != "$booted" ]; then
  echo 'rollback failed: system state differs' >&2
  exit 1
fi
for unit in sshd nginx xray xray-subscriptions-check; do
  "$systemctl" is-active --quiet "$unit.service"
done
if [ "$node" = hopper ]; then
  "$systemctl" is-active --quiet gmail-archiver.service
fi
echo 'rollback verified locally; isolated proof/probe stopped; marker and timer retained'
