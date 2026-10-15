#!/bin/sh
set -eu

case "$(/run/current-system/sw/bin/hostname)" in
  conduit)
    old=/nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990
    candidate=/nix/store/n2hdcalpxvl9zk85kap8z7nparmm8l3g-nixos-system-conduit-26.11.20260831.34ab990
    boot=/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990
    profile=/nix/store/92j5wm1b6jzjkv8rrx7xj9nahggqkglm-nixos-system-conduit-26.11.20260831.34ab990
    ;;
  hopper)
    old=/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990
    candidate=/nix/store/zylxw91hy1kyj12wi74m03as3ha9al41-nixos-system-hopper-26.11.20260831.34ab990
    boot=/nix/store/k69xg4y5d9qvp7w37p98q6vbfl0i1kgn-nixos-system-hopper-26.11.20260831.34ab990
    profile=/nix/store/w0aqhcla0ip3vp4mcwf6i8nvpdih575v-nixos-system-hopper-26.11.20260831.34ab990
    ;;
  *) echo 'rollback refused: unexpected host' >&2; exit 1 ;;
esac

readlink="$old/sw/bin/readlink"
systemctl="$old/sw/bin/systemctl"
marker=/run/stage1-probe-ingress-rollback.marker
current=$("$readlink" -f /run/current-system)

if [ "$("$readlink" -f /run/booted-system)" != "$boot" ] ||
   [ "$("$readlink" -f /nix/var/nix/profiles/system)" != "$profile" ]; then
  echo 'rollback refused: boot or profile differs from the recorded baseline' >&2
  exit 1
fi
if [ ! -e "$marker" ]; then
  if [ "$current" = "$old" ]; then
    echo 'rollback rehearsal: no-op branch executed'
    exit 0
  fi
  echo 'rollback refused: marker absent and current system changed' >&2
  exit 1
fi
if [ "$current" = "$candidate" ] && [ -x "$old/bin/switch-to-configuration" ]; then
  "$old/bin/switch-to-configuration" test
elif [ "$current" != "$old" ]; then
  echo 'rollback refused: unexpected current system or missing old switch script' >&2
  exit 1
fi

if [ "$("$readlink" -f /run/current-system)" != "$old" ]; then
  echo 'rollback failed: current system differs from old closure' >&2
  exit 1
fi
for unit in sshd.service nginx.service xray.service proxy-origin-proof.service; do
  "$systemctl" is-active --quiet "$unit"
done
if [ "$(/run/current-system/sw/bin/hostname)" = hopper ]; then
  "$systemctl" is-active --quiet gmail-archiver.service
fi
if "$systemctl" is-active --quiet proxy-preferred-probe.service; then
  echo 'rollback failed: probe service remains active' >&2
  exit 1
fi

# 订阅、证书和外部流量须人工复核；保留 marker 直到全部验收完成。
echo 'rollback restored old closure and core services; marker retained for acceptance'
