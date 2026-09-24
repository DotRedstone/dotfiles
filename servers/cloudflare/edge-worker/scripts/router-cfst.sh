#!/bin/sh
# ---
# Module: Router CloudflareST Dual-Upload Script
# Description: Run CloudflareST speedtest and upload preferred IPs to both Cloudflare Worker KV and GitHub repo
# Scope: Script
# ---
set -eu

# [Configuration]
PUBLIC_HOST="next-free.dotdot.ggff.net"
IP_UPDATE_KEY="mw878WcVzyoLBziU6cHa-NVX9nAOOWd_FfNFFPsDaKI"
GITHUB_REPO="DotRedstone/cf-ip"
GITHUB_FILE="cloudflare_ips.txt"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# [Paths]
CFST_DIR="/root/cfst"
CFST_BIN="${CFST_DIR}/CloudflareST_proxy_linux_arm64"
OUTPUT_CSV="${CFST_DIR}/result.csv"
OUTPUT_TXT="${CFST_DIR}/cloudflare_ips.txt"
GIT_REPO_DIR="${CFST_DIR}/cf-ip"

# [Speedtest]
run_speedtest() {
  if [ ! -x "${CFST_BIN}" ]; then
    echo "[!] CloudflareST executable not found at ${CFST_BIN}"
    return 1
  fi

  cd "${CFST_DIR}"
  "${CFST_BIN}" \
    -url https://cf.xiu2.xyz/url \
    -sl 5 \
    -dn 100 \
    -tl 250 \
    -o "${OUTPUT_CSV}"

  if [ -f "${OUTPUT_CSV}" ]; then
    awk -F, 'NR>1 && $1 ~ /^[0-9a-fA-F:.]+$/ {printf "%s:%s#%s-%sMB/s\n", $1, $2, $4, $6}' "${OUTPUT_CSV}" > "${OUTPUT_TXT}"
  fi
}

# [Upload to Cloudflare Worker KV]
upload_to_kv() {
  if [ ! -s "${OUTPUT_TXT}" ]; then
    echo "[!] Preferred IPs file ${OUTPUT_TXT} is empty or missing, skip KV upload"
    return 1
  fi

  timestamp="$(date +%s)"
  body="$(sed '/^[[:space:]]*$/d' "${OUTPUT_TXT}")"
  signature="$(printf '%s\n%s' "${timestamp}" "${body}" \
    | openssl dgst -sha256 -hmac "${IP_UPDATE_KEY}" -hex \
    | awk '{print $NF}')"

  echo "[*] Uploading preferred IPs to Cloudflare Worker KV..."
  curl --fail-with-body -s \
    -H "X-Edge-Timestamp: ${timestamp}" \
    -H "X-Edge-Signature: ${signature}" \
    --data-binary "${body}" \
    "https://${PUBLIC_HOST}/admin/preferred-ips"
  echo "[+] Worker KV updated successfully."
}

# [Upload to GitHub for Public Sharing]
upload_to_github() {
  if [ ! -s "${OUTPUT_TXT}" ]; then
    echo "[!] Preferred IPs file ${OUTPUT_TXT} is empty or missing, skip GitHub upload"
    return 1
  fi

  commit_date="$(date '+%Y-%m-%d %H:%M:%S')"
  commit_msg="更新Cloudflare优选IP列表 - ${commit_date}"

  # [Method 1: Local Git Repo]
  if [ -d "${GIT_REPO_DIR}/.git" ]; then
    echo "[*] Uploading to GitHub via local git repository..."
    cd "${GIT_REPO_DIR}"
    cp "${OUTPUT_TXT}" "${GITHUB_FILE}"
    git add "${GITHUB_FILE}"
    if git diff --staged --quiet; then
      echo "[-] No changes in preferred IPs, skip git commit."
      return 0
    fi
    git commit -m "${commit_msg}"
    git push origin main
    echo "[+] Pushed to GitHub repo via git."
    return 0
  fi

  # [Method 2: GitHub Contents API]
  if [ -n "${GITHUB_TOKEN}" ]; then
    echo "[*] Uploading to GitHub via REST API..."
    api_url="https://api.github.com/repos/${GITHUB_REPO}/contents/${GITHUB_FILE}"
    sha="$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "${api_url}" | grep '"sha"' | head -n 1 | cut -d'"' -f4 || true)"

    content_b64="$(base64 < "${OUTPUT_TXT}" | tr -d '\r\n')"

    if [ -n "${sha}" ]; then
      payload="$(printf '{"message":"%s","content":"%s","sha":"%s"}' "${commit_msg}" "${content_b64}" "${sha}")"
    else
      payload="$(printf '{"message":"%s","content":"%s"}' "${commit_msg}" "${content_b64}")"
    fi

    curl -s -X PUT \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "${api_url}" \
      -d "${payload}" > /dev/null
    echo "[+] Updated GitHub file via REST API."
    return 0
  fi

  echo "[!] Neither ${GIT_REPO_DIR}/.git nor GITHUB_TOKEN is available, skip GitHub upload."
}

# [Main]
main() {
  if [ "${1:-}" != "--upload-only" ]; then
    run_speedtest
  fi
  upload_to_kv || true
  upload_to_github || true
}

main "$@"
