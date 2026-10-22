# ---
# Module: Codex Account Switcher
# Description: CLI tool to switch active Codex authentication profiles and reload UI
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  codex-switch = pkgs.writeShellScriptBin "codex-switch" ''
    set -euo pipefail

    TARGET="''${1:-}"
    AUTH_DIR="$HOME/.codex"
    AUTH_FILE="$AUTH_DIR/auth.json"

    parse_auth() {
      local file="$1"
      ${pkgs.python3}/bin/python3 -c '
import json, base64, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    tokens = d.get("tokens", {})
    tok = tokens.get("id_token") or tokens.get("access_token") or ""
    parts = tok.split(".")
    if len(parts) >= 2:
        payload = parts[1] + "=" * (-len(parts[1]) % 4)
        data = json.loads(base64.urlsafe_b64decode(payload.encode()))
        email = data.get("email") or data.get("https://api.openai.com/profile", {}).get("email") or "unknown"
        acc = tokens.get("account_id") or "unknown"
        print(f"{email} (ID: {acc})")
    else:
        print("token missing/invalid")
except Exception as e:
    print(f"error: {e}")
' "$file"
    }

    list_profiles() {
      echo "=== Codex 可用账号凭据 ==="
      local current="None"
      if [ -f "$AUTH_FILE" ]; then
        current=$(parse_auth "$AUTH_FILE")
      fi
      echo "当前生效: $current"
      echo "----------------------------------------"
      local found=0
      for f in "$AUTH_DIR"/auth.*.json; do
        [ -e "$f" ] || continue
        local fname
        fname=$(basename "$f")
        local profile="''${fname#auth.}"
        profile="''${profile%.json}"
        local info
        info=$(parse_auth "$f")
        echo " - $profile -> $info"
        found=1
      done
      if [ "$found" -eq 0 ]; then
        echo " (未找到任何 ~/.codex/auth.<name>.json 凭据备份)"
      fi
      echo "========================================"
    }

    case "$TARGET" in
      ""|status|list)
        list_profiles
        echo ""
        echo "用法: codex-switch <账号名称>"
        echo "例如: codex-switch dot 或 codex-switch lc"
        ;;
      *)
        CANDIDATE="$AUTH_DIR/auth.$TARGET.json"
        if [ ! -f "$CANDIDATE" ]; then
          echo "[!] 错误: 未找到凭据文件 $CANDIDATE" >&2
          echo "请确认已在 $AUTH_DIR/ 下保存了该账号凭据。" >&2
          exit 1
        fi

        cp -f "$CANDIDATE" "$AUTH_FILE"
        chmod 600 "$AUTH_FILE"
        NEW_INFO=$(parse_auth "$AUTH_FILE")
        echo "[✓] 已成功切换至账号: $TARGET ($NEW_INFO)"

        if ${pkgs.procps}/bin/pgrep -f "opt/codex-desktop/ChatGPT" >/dev/null 2>&1; then
          echo "[*] 检测到 Codex Desktop 正在运行，正在平滑重启以重载界面..."
          ${pkgs.procps}/bin/pkill -f "opt/codex-desktop/ChatGPT" || true
          for _ in {1..20}; do
            if ! ${pkgs.procps}/bin/pgrep -f "opt/codex-desktop/ChatGPT" >/dev/null 2>&1; then
              break
            fi
            sleep 0.1
          done
          if command -v codex-desktop >/dev/null 2>&1; then
            nohup codex-desktop >/dev/null 2>&1 &
            echo "[✓] Codex Desktop 已重启，UI 界面已刷新！"
          fi
        else
          echo "[i] Codex Desktop 当前未运行，下次打开时将自动生效。"
        fi
        ;;
    esac
  '';
in {
  home.packages = [
    codex-switch
  ];
}
