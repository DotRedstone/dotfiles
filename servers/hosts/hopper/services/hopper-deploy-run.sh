#!/run/current-system/sw/bin/bash
# ---
# Script: hopper-deploy-run
# Description: Process one queued hopper deployment request from /var/lib/hopper-deploy/request
# Scope: Host
# Notes:
# - Runs as root under hopper-deploy.service; every path and command below is fixed.
# - The only caller-controlled values are ref, push and note, all validated here.
# ---
set -uo pipefail

PATH=/run/current-system/sw/bin:/run/wrappers/bin:/run/current-system/sw/sbin:/usr/bin:/bin
export PATH

BASE=/var/lib/hopper-deploy
REQ=/var/lib/dsh/workspaces/deploy-request
PROC="$BASE/processing"
DONE="$BASE/done"
OUT="$BASE/out"
LOGS="$BASE/logs"
LOCK="$BASE/.lock"

REPO=/var/lib/dsh/workspaces/nixos-config
OVERLAY=/home/dot/dotfiles-private-overlay
FLAKE_INPUT=public
ATTR='nixosConfigurations.hopper.config.system.build.toplevel'
RUN_USER=dot

mkdir -p "$REQ" "$PROC" "$DONE" "$OUT" "$LOGS"

# dot performs fetch/push on a dsh-owned checkout; whatever git writes there
# belongs to dsh. Hand ownership back even when this run fails halfway.
DIRTY=0
restore_ownership() {
  if [ "$DIRTY" = "1" ]; then
    chown -R dsh:dsh "$REPO/.git" 2>/dev/null || true
  fi
}
trap restore_ownership EXIT

# Serialise runs; a second trigger while one is running simply exits.
exec 9>"$LOCK"
flock -n 9 || exit 0

req=$(find "$REQ" -maxdepth 1 -type f -name '*.json' -print 2>/dev/null | sort | head -n 1)
[ -n "$req" ] || exit 0

uuid=$(basename "$req" .json)
case "$uuid" in
  ''|.|..|*[!A-Za-z0-9._-]*)
    # Park invalid names outside request/ so the path unit cannot spin on them.
    mkdir -p "$BASE/rejected"
    mv -f -- "$req" "$BASE/rejected/$(date +%s%N)-invalid" 2>/dev/null || true
    echo "reject: unsafe request name: $uuid" >&2
    exit 0
    ;;
esac

STARTED=$(date -Is)
LOG="$LOGS/$uuid.log"
: >"$LOG"
exec >>"$LOG" 2>&1

REQUEST_JSON="$PROC/$uuid.json"
mv -f "$req" "$REQUEST_JSON" || { echo "reject: cannot move request"; exit 0; }
sleep 1

REF=""
PUSH="false"
NOTE=""
OUTPATH=""

finish() {
  local status="$1" msg="${2:-}"
  local tailtxt
  tailtxt=$(tail -n 60 "$LOG" 2>/dev/null | tail -c 6000)
  jq -n \
    --arg uuid "$uuid" \
    --arg status "$status" \
    --arg ref "$REF" \
    --arg note "$NOTE" \
    --argjson push "$PUSH" \
    --arg outPath "$OUTPATH" \
    --arg error "$msg" \
    --arg startedAt "$STARTED" \
    --arg finishedAt "$(date -Is)" \
    --arg logTail "$tailtxt" \
    '{uuid:$uuid,status:$status,ref:$ref,push:$push,note:$note,outPath:$outPath,error:$error,startedAt:$startedAt,finishedAt:$finishedAt,logTail:$logTail}' \
    >"$OUT/.$uuid.json.tmp"
  mv -f "$OUT/.$uuid.json.tmp" "$OUT/$uuid.json"
  chmod 0644 "$OUT/$uuid.json"
  cp -f "$REQUEST_JSON" "$DONE/$uuid.json" 2>/dev/null || true
  rm -f "$REQUEST_JSON"
  echo "result: $status ${msg}"
}

fail() {
  finish "failed" "$1"
  exit 1
}

echo "== request $uuid =="
echo "started: $STARTED"

# --- request file shape ------------------------------------------------
[ -f "$REQUEST_JSON" ] && [ ! -L "$REQUEST_JSON" ] || fail "request is not a regular file"
owner=$(stat -c '%U' "$REQUEST_JSON" 2>/dev/null)
case "$owner" in dsh|root) ;; *) fail "request owner must be dsh or root (got ${owner:-unknown})" ;; esac
size=$(stat -c '%s' "$REQUEST_JSON" 2>/dev/null || echo 0)
[ "$size" -le 8192 ] || fail "request too large ($size bytes)"
[ "$size" -gt 0 ] || fail "request is empty"

jq -e '
  type == "object"
  and (keys | sort) == ["action", "note", "push", "ref"]
  and .action == "deploy"
  and (.ref | type) == "string" and (.ref | test("^[0-9a-f]{40}$"))
  and (.push | type) == "boolean"
  and (.note | type) == "string" and (.note | length) <= 500
' "$REQUEST_JSON" >/dev/null 2>&1 || fail "invalid request schema (need exactly action/ref/push/note)"

REF=$(jq -r '.ref' "$REQUEST_JSON")
PUSH=$(jq -r '.push' "$REQUEST_JSON")
NOTE=$(jq -r '.note' "$REQUEST_JSON")
echo "ref=$REF push=$PUSH"

# --- ref must exist in the deploy checkout -----------------------------
git_repo() { runuser -u dsh -- git -C "$REPO" "$@"; }
git_repo cat-file -e "$REF^{commit}" 2>/dev/null || fail "commit $REF not found in $REPO"
echo "commit present: $(git_repo rev-parse --short "$REF")"

# --- optional push -----------------------------------------------------
if [ "$PUSH" = "true" ]; then
  branch=$(git_repo rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -n "$branch" ] && [ "$branch" != "HEAD" ] || fail "checkout is detached; cannot pick a push target branch"
  # Fast-forward guard: the deploy checkout is synced by the caller (dsh) with
  # `git pull --rebase`. Never let this script rebase or merge on its own.
  echo "checking fast-forward against origin/$branch"
  DIRTY=1
  runuser -u "$RUN_USER" -- env HOME=/home/dot \
    git -c safe.directory="$REPO" -C "$REPO" \
    fetch --quiet origin "+refs/heads/$branch:refs/remotes/origin/$branch" \
    || fail "git fetch failed"
  if ! runuser -u "$RUN_USER" -- env HOME=/home/dot \
      git -c safe.directory="$REPO" -C "$REPO" \
      merge-base --is-ancestor "origin/$branch" "$REF"; then
    fail "push would not fast-forward: origin/$branch has commits missing from $REF; run 'git -C $REPO pull --rebase' first"
  fi

  echo "pushing $REF to origin/$branch"
  runuser -u "$RUN_USER" -- env HOME=/home/dot GIT_TERMINAL_PROMPT=0 \
    GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new' \
    git -c safe.directory="$REPO" -C "$REPO" push origin "$REF:refs/heads/$branch" \
    || fail "git push failed (does $RUN_USER have GitHub credentials?)"
fi

# --- refresh overlay input and build -----------------------------------
echo "updating flake input: $FLAKE_INPUT"
runuser -u "$RUN_USER" -- env HOME=/home/dot bash -c "cd '$OVERLAY' && exec nix flake update '$FLAKE_INPUT'" \
  || fail "nix flake update failed"

echo "building $ATTR"
OUTPATH=$(runuser -u "$RUN_USER" -- env HOME=/home/dot \
  nix build "path:$OVERLAY#$ATTR" --no-link --print-out-paths) \
  || fail "nix build failed"
OUTPATH=$(printf '%s\n' "$OUTPATH" | tail -n 1)
[ -n "$OUTPATH" ] && [ -x "$OUTPATH/bin/switch-to-configuration" ] || fail "build produced no usable system closure"
echo "closure: $OUTPATH"

# --- activate ----------------------------------------------------------
echo "set system profile"
nix-env -p /nix/var/nix/profiles/system --set "$OUTPATH" || fail "nix-env --set failed"

echo "switch-to-configuration switch"
"$OUTPATH/bin/switch-to-configuration" switch || fail "switch-to-configuration failed"

finish "ok" ""
