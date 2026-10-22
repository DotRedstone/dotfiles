# ---
# Module: Codex Account Switcher
# Description: CLI tool to switch isolated Codex profiles (both CLI & Desktop GUI) without re-authentication
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  codex-switch = pkgs.writeShellScriptBin "codex-switch" ''
    set -euo pipefail

    TARGET="''${1:-}"
    AUTH_DIR="$HOME/.codex"
    AUTH_FILE="$AUTH_DIR/auth.json"
    CONFIG_DIR="$HOME/.config/Codex"
    PROFILES_DIR="$HOME/.config/Codex-profiles"
    CURRENT_MARKER="$PROFILES_DIR/current"

    mkdir -p "$PROFILES_DIR"

    # Helper to parse identity from an auth.json file
    parse_auth() {
      local file="$1"
      if [ ! -f "$file" ]; then
        echo "未配置凭据"
        return
      fi
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
        print("token 格式未知")
except Exception as e:
    print(f"解析失败 ({e})")
' "$file"
    }

    # Determine current active profile name
    get_current_profile() {
      if [ -f "$CURRENT_MARKER" ]; then
        cat "$CURRENT_MARKER"
      else
        # Guess from current auth.json
        if [ -f "$AUTH_FILE" ]; then
          local info
          info=$(parse_auth "$AUTH_FILE")
          if [[ "$info" == *"lc2724236945"* ]]; then
            echo "lc"
          elif [[ "$info" == *"dotredstone0123"* ]]; then
            echo "dot"
          else
            echo "default"
          fi
        else
          echo "unknown"
        fi
      fi
    }

    show_status() {
      local curr
      curr=$(get_current_profile)
      echo "=== Codex 多账号 Profile 状态 ==="
      echo "当前活跃 Profile: [$curr]"
      if [ -f "$AUTH_FILE" ]; then
        echo "当前生效身份: $(parse_auth "$AUTH_FILE")"
      else
        echo "当前生效身份: 未登录"
      fi
      echo "----------------------------------------"
      echo "可用账号 Profile 列表:"
      for name in dot lc; do
        local pdir="$PROFILES_DIR/$name"
        local auth_p="$pdir/auth.json"
        [ -f "$auth_p" ] || auth_p="$AUTH_DIR/auth.$name.json"
        local id_info="未初始化"
        if [ -f "$auth_p" ]; then
          id_info=$(parse_auth "$auth_p")
        fi
        local has_gui="无 GUI 缓存 (需首次授权)"
        if [ "$curr" = "$name" ] && [ -d "$CONFIG_DIR" ]; then
          has_gui="✓ GUI 数据就绪 (当前活跃)"
        elif [ -d "$pdir/Codex" ]; then
          has_gui="✓ GUI 数据就绪 (免密秒切)"
        fi
        echo " - [$name] -> $id_info [$has_gui]"
      done
      echo "========================================"
      echo ""
      echo "用法: codex-switch <账号名称>"
      echo "示例: codex-switch dot  或  codex-switch lc"
    }

    case "$TARGET" in
      ""|status|list)
        show_status
        ;;
      dot|lc)
        CURRENT_PROF=$(get_current_profile)
        if [ "$CURRENT_PROF" = "$TARGET" ]; then
          echo "[i] 当前已经是 $TARGET 账号 ($(parse_auth "$AUTH_FILE"))。"
          echo "若需重新加载客户端，请直接运行: codex-switch reload"
          exit 0
        fi

        echo "[*] 开始切换账号: [$CURRENT_PROF] -> [$TARGET]..."

        # 1. Stop running client if active
        WAS_RUNNING=0
        if ${pkgs.procps}/bin/pgrep -f "opt/codex-desktop/ChatGPT" >/dev/null 2>&1; then
          WAS_RUNNING=1
          echo "[*] 正在优雅关闭当前运行中的 Codex Desktop..."
          ${pkgs.procps}/bin/pkill -f "opt/codex-desktop/ChatGPT" || true
          for _ in {1..30}; do
            if ! ${pkgs.procps}/bin/pgrep -f "opt/codex-desktop/ChatGPT" >/dev/null 2>&1; then
              break
            fi
            sleep 0.1
          done
        fi

        # 2. Archive current profile
        if [ "$CURRENT_PROF" != "unknown" ]; then
          mkdir -p "$PROFILES_DIR/$CURRENT_PROF"
          if [ -d "$CONFIG_DIR" ]; then
            # Clean up stale chromium locks before archiving
            rm -f "$CONFIG_DIR"/SingletonLock "$CONFIG_DIR"/SingletonSocket "$CONFIG_DIR"/SingletonCookie 2>/dev/null || true
            rm -rf "$PROFILES_DIR/$CURRENT_PROF/Codex"
            mv "$CONFIG_DIR" "$PROFILES_DIR/$CURRENT_PROF/Codex"
          fi
          if [ -f "$AUTH_FILE" ]; then
            cp -f "$AUTH_FILE" "$PROFILES_DIR/$CURRENT_PROF/auth.json"
          fi
          echo "[✓] 已安全归档当前 [$CURRENT_PROF] 的桌面会话与凭据"
        fi

        # 3. Restore target profile
        mkdir -p "$PROFILES_DIR/$TARGET"
        if [ -d "$PROFILES_DIR/$TARGET/Codex" ]; then
          rm -rf "$CONFIG_DIR"
          mv "$PROFILES_DIR/$TARGET/Codex" "$CONFIG_DIR"
          # Clean up stale locks in restored profile
          rm -f "$CONFIG_DIR"/SingletonLock "$CONFIG_DIR"/SingletonSocket "$CONFIG_DIR"/SingletonCookie 2>/dev/null || true
          echo "[✓] 已挂载 [$TARGET] 的专属桌面会话数据 (免密进入)"
        else
          mkdir -p "$CONFIG_DIR"
          echo "[i] 首次进入 [$TARGET] 账号环境，已初始化独立桌面目录"
        fi

        # 4. Activate target auth.json
        if [ -f "$PROFILES_DIR/$TARGET/auth.json" ]; then
          cp -f "$PROFILES_DIR/$TARGET/auth.json" "$AUTH_FILE"
        elif [ -f "$AUTH_DIR/auth.$TARGET.json" ]; then
          cp -f "$AUTH_DIR/auth.$TARGET.json" "$AUTH_FILE"
          cp -f "$AUTH_DIR/auth.$TARGET.json" "$PROFILES_DIR/$TARGET/auth.json"
        fi
        chmod 600 "$AUTH_FILE"

        # Update marker
        echo "$TARGET" > "$CURRENT_MARKER"
        echo "[✓] 已成功切换至账号: [$TARGET] ($(parse_auth "$AUTH_FILE"))"

        # 5. Relaunch client if it was running or always
        if [ "$WAS_RUNNING" -eq 1 ] || [ "''${2:-}" = "--launch" ]; then
          echo "[*] 正在启动 [$TARGET] 的 Codex Desktop 客户端..."
          if command -v codex-desktop >/dev/null 2>&1; then
            nohup codex-desktop >/dev/null 2>&1 &
            echo "[✓] 客户端已成功启动！"
          fi
        else
          echo "[i] 切换完成。下次打开 Codex 客户端时将自动加载 [$TARGET] 环境。"
        fi
        ;;
      reload)
        echo "[*] 正在平滑重启当前活跃客户端..."
        ${pkgs.procps}/bin/pkill -f "opt/codex-desktop/ChatGPT" || true
        for _ in {1..30}; do
          if ! ${pkgs.procps}/bin/pgrep -f "opt/codex-desktop/ChatGPT" >/dev/null 2>&1; then
            break
          fi
          sleep 0.1
        done
        if command -v codex-desktop >/dev/null 2>&1; then
          nohup codex-desktop >/dev/null 2>&1 &
          echo "[✓] 已成功重新拉起客户端！"
        fi
        ;;
      *)
        echo "[!] 未知命令或账号名称: '$TARGET'" >&2
        echo "支持的账号: dot | lc" >&2
        echo "查看状态: codex-switch" >&2
        exit 1
        ;;
    esac
  '';
in {
  home.packages = [
    codex-switch
  ];
}
