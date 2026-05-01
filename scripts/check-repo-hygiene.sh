#!/usr/bin/env bash

# ---
# Module: Repo Hygiene Check
# Description: Pre-commit checks for secrets, persistence paths, and dangerous files
# Scope: Script
# ---

# Usage:
# Run before commit:
# ./scripts/check-repo-hygiene.sh

set -euo pipefail

# Repo root
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# [Section Headers]
print_header() {
    echo -e "\n\033[1;34m>>> $1\033[0m"
}

print_success() {
    echo -e "\033[1;32m✓ $1\033[0m"
}

print_error() {
    echo -e "\033[1;31m✗ $1\033[0m"
}

print_warning() {
    echo -e "\033[1;33m! $1\033[0m"
}

FAILED=0

# A. Forbidden persistence paths
print_header "Checking Forbidden Persistence Paths"
FORBIDDEN_PATHS=("\"/etc/shadow\"" "\"/etc/passwd\"" "\"/etc/group\"" "\"/etc/gshadow\"" "\"/var/log\"")
PERSIST_FILES=(modules/system/persistence.nix modules/system/persistence/*.nix)

FOUND_FORBIDDEN=0
for path in "${FORBIDDEN_PATHS[@]}"; do
    # Use grep -l to just find files
    if grep -r "$path" modules/system/persistence.nix modules/system/persistence/ 2>/dev/null; then
        print_error "Forbidden path found: $path"
        FOUND_FORBIDDEN=1
    fi
done

if [ "$FOUND_FORBIDDEN" -eq 0 ]; then
    print_success "No forbidden persistence paths found."
else
    FAILED=1
fi

# B. Obvious tracked secret patterns
print_header "Checking Tracked Secret Patterns"
SECRET_PATTERNS=(
    "BEGIN (OPENSSH|RSA|DSA|EC|AGE) PRIVATE KEY"
    "AKIA[0-9A-Z]{16}"
    "ghp_[A-Za-z0-9_]{20,}"
    "xox[baprs]-[A-Za-z0-9-]+"
    "sk-[A-Za-z0-9_-]{20,}"
    "AIza[0-9A-Za-z_-]{20,}"
)

FOUND_SECRETS=0
for pattern in "${SECRET_PATTERNS[@]}"; do
    # Only show file:line
    if git grep -nE "$pattern" -- ':(exclude)secrets/' ':(exclude)home/dot/fcitx5/rime/patches/' 2>/dev/null; then
        print_error "Potential secret pattern found: $pattern"
        FOUND_SECRETS=1
    fi
done

if [ "$FOUND_SECRETS" -eq 0 ]; then
    print_success "No obvious tracked secret patterns found."
else
    FAILED=1
fi

# C. SOPS sanity
print_header "Checking SOPS Encryption Sanity"
SOPS_FILES=("secrets.yaml" "secrets/noctalia.yaml")

FOUND_DECRYPTED=0
for file in "${SOPS_FILES[@]}"; do
    if [ -f "$file" ]; then
        if ! grep -q "ENC\[AES256_GCM" "$file"; then
            print_error "SOPS file appears to be decrypted or unencrypted: $file"
            FOUND_DECRYPTED=1
        else
            print_success "SOPS file is encrypted: $file"
        fi
    fi
done

if [ "$FOUND_DECRYPTED" -eq 1 ]; then
    FAILED=1
fi

# D. Dangerous untracked files
print_header "Checking for Dangerous Untracked Files"
DANGEROUS_PATTERNS=(
    "\.env"
    "\.env\.*"
    ".*\.pem"
    ".*\.key"
    ".*\.agekey"
    "keys\.txt"
    ".*\.decrypted\.yaml"
    ".*\.plain\.yaml"
    ".*\.dec\.yaml"
    "result"
    "result-.*"
)

FOUND_DANGEROUS=0
# Get all untracked and ignored files
STATUS_OUTPUT=$(git status --short --ignored)

while read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    
    FILE_PATH=$(echo "$line" | cut -c 4-)
    FILE_STATUS=$(echo "$line" | cut -c 1-2)
    
    for pattern in "${DANGEROUS_PATTERNS[@]}"; do
        if [[ "$(basename "$FILE_PATH")" =~ ^$pattern$ ]]; then
            if [[ "$FILE_STATUS" == "!!" ]]; then
                print_warning "Ignored dangerous file: $FILE_PATH"
            elif [[ "$FILE_STATUS" == "??" ]]; then
                print_error "Untracked DANGEROUS file found: $FILE_PATH (Add to .gitignore or delete!)"
                FOUND_DANGEROUS=1
            fi
        fi
    done
done <<< "$STATUS_OUTPUT"

if [ "$FOUND_DANGEROUS" -eq 1 ]; then
    FAILED=1
else
    print_success "No untracked dangerous files found."
fi

# E. Basic repo status
print_header "Repository Status"
git status --short

if [ "$FAILED" -eq 1 ]; then
    print_header "Hygiene Check FAILED"
    exit 1
else
    print_header "Hygiene Check PASSED"
    exit 0
fi
