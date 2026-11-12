#!/usr/bin/env bash
# ---
# Script: show-subscription-urls.sh
# Description: 解密 SOPS 生成当前可用的各客户端订阅链接
# Scope: Script
# ---
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_FILE="${REPO_DIR}/servers/secrets/cloudflare.yaml"

if [ ! -f "${SECRETS_FILE}" ]; then
  echo "错误: 未找到密钥文件 ${SECRETS_FILE}" >&2
  exit 1
fi

sops decrypt --output-type json "${SECRETS_FILE}" | python3 -c '
import sys, json

data = json.load(sys.stdin).get("edge_next", {})
host = "edge-next.bdot.in"
sub_token = data.get("subscription_token", "")
cfg_tokens = data.get("config_tokens", {})

print("\n" + "="*56)
print(" 🚀 Clash / Mihomo 配置订阅（包含全部节点与分流策略，推荐）")
print("="*56)
for p in ["desktop", "mobile", "router"]:
    t = cfg_tokens.get(p, "")
    print(f"[{p:7s}] https://{host}/clash/{t}/{p}")

print("\n" + "="*56)
print(" 🌐 通用单节点列表订阅（适用于 v2rayN / Shadowrocket 等）")
print("="*56)
print(f"[纯文本]   https://{host}/sub/{sub_token}?format=plain")
print(f"[Base64]   https://{host}/sub/{sub_token}")
print("="*56 + "\n")
'
