# ---
# Module: Chrome - Vertical Tabs
# Description: Activation script to patch Chrome profile for vertical tabs
# ---

{ config, lib, pkgs, ... }: {
  # Chrome stores the selected tab-strip layout as a profile preference.
  # There is no stable enterprise policy for this yet, so patch the profile
  # preference directly while still enabling the feature at launch via flags.
  home.activation.chromeVerticalTabs =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      prefs="${config.xdg.configHome}/google-chrome/Default/Preferences"
      mkdir -p "$(dirname "$prefs")"

      if [ -f "$prefs" ]; then
        tmp="$(mktemp "$prefs.XXXXXX")"
        if ${pkgs.jq}/bin/jq '.vertical_tabs.enabled = true' "$prefs" > "$tmp"; then
          chmod --reference="$prefs" "$tmp" 2>/dev/null || true
          mv "$tmp" "$prefs"
        else
          rm -f "$tmp"
          echo "Failed to patch Chrome vertical tabs preference: $prefs" >&2
        fi
      else
        printf '%s\n' '{"vertical_tabs":{"enabled":true}}' > "$prefs"
      fi
    '';
}
