#!/usr/bin/env bash

# ---
# Script: check-persistence-health.sh
# Description: Impermanence setup health check for NixOS
# ---

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function log_err() { echo -e "${RED}[ERROR]${NC} $1"; }
function log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "Starting Impermanence Health Check..."

# 1. Check /persist mount status
if findmnt /persist | grep -q "rw"; then
    log_ok "/persist is mounted read-write"
else
    log_err "/persist is not mounted or is read-only"
    exit 1
fi

# 2. Check /persist writability
if sudo test -w /persist; then
    log_ok "/persist is writable by root"
else
    log_err "/persist is not writable by root"
    exit 1
fi

# 3. Check secrets existence
for f in dot.passwd root.passwd; do
    if [ -f "/persist/secrets/$f" ]; then
        log_ok "/persist/secrets/$f exists"
    else
        log_err "/persist/secrets/$f is missing"
        exit 1
    fi
done

# 4. Check permissions and ownership
for f in dot.passwd root.passwd; do
    PERM=$(stat -c "%a" "/persist/secrets/$f")
    OWNER=$(stat -c "%U:%G" "/persist/secrets/$f")
    if [ "$PERM" == "600" ] && [ "$OWNER" == "root:root" ]; then
        log_ok "/persist/secrets/$f has correct permissions (600) and ownership (root:root)"
    else
        log_err "/persist/secrets/$f has wrong permissions ($PERM) or ownership ($OWNER)"
        exit 1
    fi
done

# 5. Check hash format (must start with $6$ for sha-512)
for f in dot.passwd root.passwd; do
    if sudo head -c 3 "/persist/secrets/$f" | grep -q '^\$6\$'; then
        log_ok "/persist/secrets/$f uses SHA-512 hash format"
    else
        log_err "/persist/secrets/$f hash format is incorrect (should start with \$6\$)"
        exit 1
    fi
done

# 6. Check Btrfs property
if btrfs property get /persist ro 2>/dev/null | grep -q "ro=false"; then
    log_ok "Btrfs property /persist ro is false"
else
    log_warn "Btrfs property /persist ro check skipped or not false"
fi

# 7. Check codebase for shadow persistence
# Assuming the script is run from the root of the dotfiles repo
FORBIDDEN="/etc/shadow|/etc/passwd|/etc/group|/etc/gshadow"
if grep -rE "$FORBIDDEN" modules/system/persistence.nix 2>/dev/null | grep -v "^#"; then
    log_err "Forbidden account database persistence found in modules/system/persistence.nix!"
    exit 1
else
    log_ok "No forbidden account database persistence found in codebase"
fi

echo -e "\n${GREEN}Health check passed!${NC}"
