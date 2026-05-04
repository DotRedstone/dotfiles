# ---
# Module: Noctalia Scripts
# Description: Helper scripts for Noctalia plugins
# Scope: Home Manager
# ---

{ pkgs, ... }:

let
  antigravity-usage-json = pkgs.writeShellScriptBin "antigravity-usage-json" ''
    set -euo pipefail

    CACHE_DIR="''${HOME}/.cache/noctalia/model-usage"
    CACHE_FILE="''${CACHE_DIR}/antigravity.json"

    fail_json() {
      local msg="''${1:-unknown error}"
      printf '{"ok":false,"provider":"antigravity","error":"%s"}\n' "$msg"
      exit 0
    }

    ${pkgs.coreutils}/bin/mkdir -p "$CACHE_DIR"

    RAW=""
    if ${pkgs.coreutils}/bin/env command -v antigravity-usage >/dev/null 2>&1; then
      RAW=$(antigravity-usage --json 2>/dev/null || true)
    elif [ -x "''${HOME}/.nix-profile/bin/antigravity-usage" ]; then
      RAW=$("''${HOME}/.nix-profile/bin/antigravity-usage" --json 2>/dev/null || true)
    fi

    # Skip 'antigravity usage' as it may trigger file opening behavior in some CLI wrappers


    if [ -z "$RAW" ] && ${pkgs.coreutils}/bin/env command -v pnpm >/dev/null 2>&1 && ${pkgs.coreutils}/bin/env command -v node >/dev/null 2>&1; then
      RAW=$(pnpm dlx antigravity-usage --json 2>/dev/null || true)
    elif [ -z "$RAW" ] && [ -x "${pkgs.pnpm}/bin/pnpm" ] && [ -x "${pkgs.nodejs}/bin/node" ]; then
      RAW=$("${pkgs.pnpm}/bin/pnpm" dlx antigravity-usage --json 2>/dev/null || true)
    fi

    if [ -z "$RAW" ]; then
      fail_json "antigravity usage collector unavailable"
    fi

    if ! echo "$RAW" | ${pkgs.jq}/bin/jq empty 2>/dev/null; then
      fail_json "invalid json"
    fi

    RESULT=$(echo "$RAW" | ${pkgs.jq}/bin/jq '
      def redact_email:
        if . == null then null
        elif type == "string" then
          (split("@") | if length > 1 then
            (.[0] | if length > 2 then .[:2] + ("*" * (length - 2)) else . end) + "@" + .[1]
          else "***" end)
        else .
        end;

      def pct_to_100(v):
        if v == null then 0
        elif v <= 1 then (v * 100 | round)
        else (v | round)
        end;

      {
        ok: true,
        provider: "antigravity",
        fetchedAt: (now | todate),
        promptCredits: (
          if (.prompt_credits or .promptCredits) then
            (.prompt_credits // .promptCredits) as $pc |
            {
              available: ($pc.available // 0),
              monthly: ($pc.monthly // 0),
              usedPercent: (
                if ($pc.usedPercent // $pc.usedPercentage // null) != null then
                  pct_to_100($pc.usedPercent // $pc.usedPercentage)
                elif ($pc.monthly // 0) > 0 then
                  ((1 - (($pc.available // 0) / $pc.monthly)) * 100 | round)
                else 0 end
              ),
              remainingPercent: (
                if ($pc.remainingPercent // $pc.remainingPercentage // null) != null then
                  pct_to_100($pc.remainingPercent // $pc.remainingPercentage)
                elif ($pc.monthly // 0) > 0 then
                  ((($pc.available // 0) / $pc.monthly) * 100 | round)
                else 100 end
              )
            }
          else null
          end
        ),
        models: [
          (.models // .quotas // [] | .[] |
            (
              if (.used_percent // .usage_percent // null) != null then
                {
                  label: (.label // .model // .name // "Unknown"),
                  usedPercent: pct_to_100(.used_percent // .usage_percent),
                  remainingPercent: ([0, (100 - pct_to_100(.used_percent // .usage_percent))] | max),
                  resetTime: (.reset_time // .resets_at // .resetTime // null),
                  isExhausted: (.is_exhausted // (.remaining == 0) // false)
                }
              elif (.remainingPercentage // .remaining_percent // null) != null then
                (pct_to_100(.remainingPercentage // .remaining_percent)) as $rp |
                {
                  label: (.label // .model // .name // "Unknown"),
                  usedPercent: ([0, (100 - $rp)] | max),
                  remainingPercent: $rp,
                  resetTime: (.reset_time // .resets_at // .resetTime // null),
                  isExhausted: (.is_exhausted // .isExhausted // ($rp <= 0) // false)
                }
              else
                {
                  label: (.label // .model // .name // "Unknown"),
                  usedPercent: 0,
                  remainingPercent: 100,
                  resetTime: (.reset_time // .resets_at // .resetTime // null),
                  isExhausted: (.is_exhausted // .isExhausted // false)
                }
              end
            )
          )
        ]
      }
    ') || fail_json "jq processing failed"

    TMPFILE=$(${pkgs.coreutils}/bin/mktemp "''${CACHE_DIR}/.antigravity.json.XXXXXX")
    echo "$RESULT" > "$TMPFILE"
    ${pkgs.coreutils}/bin/mv "$TMPFILE" "$CACHE_FILE"

    echo "$RESULT"
  '';
in
{
  home.packages = [ antigravity-usage-json ];
}
