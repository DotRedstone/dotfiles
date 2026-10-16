#!/bin/sh
set -eu

source_script=$(CDPATH='' cd -- "$(dirname -- "$0")/../scripts" && pwd)/optimizer-probe-rollback.sh
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
export FIXTURE_ROOT="$fixture"
old="$fixture/nix/store/73qxjfv9l6fjp73fvqpi31a02gnnvwd4-nixos-system-conduit-26.11.20260831.34ab990"
candidate="$fixture/nix/store/flnlzx6zqv3g2ai82yfyvxr47r6ml418-nixos-system-conduit-26.11.20260831.34ab990"
booted="$fixture/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990"
export FIXTURE_OLD="$old"
mkdir -p "$old/sw/bin" "$old/bin" "$candidate" "$booted" \
  "$fixture/nix/var/nix/profiles" "$fixture/run/secrets/rendered" \
  "$fixture/run/secrets/xray" "$fixture/run/credentials/xray.service" "$fixture/boot/grub"
sed -e 's#IFS= read -r node < /proc/sys/kernel/hostname#node=conduit#' \
  -e 's#/nix/var/nix/profiles/system#@PROFILE@#g' \
  -e "s#/nix/#$fixture/nix/#g" -e "s#/run/#$fixture/run/#g" \
  -e "s#/boot/#$fixture/boot/#g" \
  -e "s#@PROFILE@#$fixture/nix/var/nix/profiles/system#g" \
  "$source_script" > "$fixture/rollback.sh"
chmod 0700 "$fixture/rollback.sh"
sed 's/^node=conduit$/node=hopper/' "$fixture/rollback.sh" > "$fixture/hopper-rollback.sh"
grep -Fq 'candidate=/nix/store/89vwm78ydgckkv0jqw0sfdgg08hg2ggw-nixos-system-hopper-26.11.20260831.34ab990' \
  "$source_script"
if "$fixture/hopper-rollback.sh" test >/dev/null 2>&1; then
  echo 'Hopper without its old closure unexpectedly accepted' >&2
  exit 1
fi
for command in readlink awk grep cmp cat; do
  ln -s "$(command -v "$command")" "$old/sw/bin/$command"
done
cat > "$old/sw/bin/id" <<'EOF'
#!/bin/sh
printf '0\n'
EOF
cat > "$old/sw/bin/stat" <<'EOF'
#!/bin/sh
printf '0:0:600\n'
EOF
cat > "$old/sw/bin/systemctl" <<'EOF'
#!/bin/sh
case "$1:$2" in
  show:stage1-optimizer-probe-rollback.timer) cat "$FIXTURE_ROOT/timer-state" ;;
  show:stage1-optimizer-probe-rollback.service)
    printf 'argv[]=%s/run/stage1-optimizer-probe-rollback.sh %s\n' \
      "$FIXTURE_ROOT" "$(cat "$FIXTURE_ROOT/mode")"
    ;;
  restart:*|is-active:*) exit 0 ;;
  *) exit 1 ;;
esac
EOF
cat > "$old/sw/bin/nix-env" <<'EOF'
#!/bin/sh
ln -sfn "$4" "$2"
EOF
cat > "$old/sw/bin/curl" <<'EOF'
#!/bin/sh
printf expected
EOF
cat > "$old/bin/switch-to-configuration" <<'EOF'
#!/bin/sh
ln -sfn "$FIXTURE_OLD" "$FIXTURE_ROOT/run/current-system"
if [ "$1" = switch ]; then
  printf 'menuentry "NixOS" {\n linux /kernel init=%s/init\n}\n' "$FIXTURE_OLD" \
    > "$FIXTURE_ROOT/boot/grub/grub.cfg"
fi
EOF
chmod 0700 "$old/sw/bin/id" "$old/sw/bin/stat" "$old/sw/bin/systemctl" \
  "$old/sw/bin/nix-env" "$old/sw/bin/curl" "$old/bin/switch-to-configuration"
printf '{"email":"managed:rotation","email":"managed:canary"}\n' \
  > "$fixture/run/secrets/rendered/xray-node.json"
cp "$fixture/run/secrets/rendered/xray-node.json" \
  "$fixture/run/credentials/xray.service/config.json"
for name in websocket reality cdn; do
  printf '/sub/%s' "$name" > "$fixture/run/secrets/xray/subscription_${name}_path"
  printf expected > "$fixture/run/secrets/xray/subscription_${name}_content"
done
ln -s "$booted" "$fixture/run/booted-system"
marker="$fixture/run/stage1-optimizer-probe-rollback.marker"
profile="$fixture/nix/var/nix/profiles/system"

reset_old() {
  ln -sfn "$old" "$fixture/run/current-system"
  ln -sfn "$old" "$profile"
  printf 'menuentry "NixOS" {\n linux /kernel init=%s/init\n}\n' "$old" \
    > "$fixture/boot/grub/grub.cfg"
  printf inactive > "$fixture/timer-state"
  rm -f "$marker"
}
assert_old() {
  [ "$(readlink -f "$fixture/run/current-system")" = "$old" ]
  [ "$(readlink -f "$profile")" = "$old" ]
  grep -Fq "init=$old/init" "$fixture/boot/grub/grub.cfg"
  [ -f "$marker" ]
  [ "$(cat "$fixture/timer-state")" = active ]
}
reset_old
output=$("$fixture/rollback.sh" test 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
printf '%s\n' "$output" | grep -Fq 'no-op branch executed'
output=$("$fixture/rollback.sh" switch 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
printf '%s\n' "$output" | grep -Fq 'no-op branch executed'
ln -sfn "$candidate" "$fixture/run/current-system"
if "$fixture/rollback.sh" test >/dev/null 2>&1; then
  echo 'candidate without marker unexpectedly accepted' >&2
  exit 1
fi
printf '%s\n' "conduit test $old $candidate $booted" > "$marker"
printf inactive > "$fixture/timer-state"
ln -sfn "$candidate" "$fixture/run/booted-system"
if "$fixture/rollback.sh" test >/dev/null 2>&1; then
  echo 'changed booted system unexpectedly accepted' >&2
  exit 1
fi
ln -sfn "$booted" "$fixture/run/booted-system"
printf '%s\n' 'stale marker' > "$marker"
if "$fixture/rollback.sh" test >/dev/null 2>&1; then
  echo 'stale marker unexpectedly accepted' >&2
  exit 1
fi
for mode in test switch; do
  reset_old
  printf '%s' "$mode" > "$fixture/mode"
  printf active > "$fixture/timer-state"
  printf '%s\n' "conduit $mode $old $candidate $booted" > "$marker"
  ln -sfn "$candidate" "$fixture/run/current-system"
  if [ "$mode" = switch ]; then
    ln -sfn "$candidate" "$profile"
    printf 'menuentry "NixOS" {\n linux /kernel init=%s/init\n}\n' "$candidate" \
      > "$fixture/boot/grub/grub.cfg"
  fi
  "$fixture/rollback.sh" "$mode" >/dev/null
  assert_old
done
printf 'optimizer rollback fixture passed: no-op, identity refusals, Hopper path, test and switch recovery\n'
