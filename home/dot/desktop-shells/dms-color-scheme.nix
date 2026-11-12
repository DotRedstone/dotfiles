# ---
# Module: DMS Color Scheme Bridge
# Description: Propagates DMS light/dark mode to Antigravity and VS Code-family editors
# Scope: Home Manager
# ---
# Notes:
# - Appends to matugen/config.toml with mkAfter; DMS only reads [templates.*] before [config].
# - Editor themes are copied only into existing noctalia.noctaliatheme-* extension directories.

{ pkgs, lib, config, ... }:
let
  homeDir = config.home.homeDirectory;
  jq = "${pkgs.jq}/bin/jq";
  dmsTemplates = "${config.home.profileDirectory}/share/quickshell/dms/matugen/templates";

  antigravityTemplate = pkgs.writeText "antigravity-theme.json.template" ''
    {
      "userSettings": {
        "customThemeSeedsDark": {
          "background": "{{colors.surface.dark.hex}}",
          "foregroundOverride": "{{colors.on_surface.dark.hex}}",
          "primary": "{{colors.primary.dark.hex}}"
        },
        "customThemeSeedsLight": {
          "background": "{{colors.surface.light.hex}}",
          "foregroundOverride": "{{colors.on_surface.light.hex}}",
          "primary": "{{colors.primary.light.hex}}"
        },
        "themeMode": "{{ mode }}"
      }
    }
  '';

  # [Antigravity Agent Manager]
  antigravitySync = pkgs.writeShellScript "dms-antigravity-sync" ''
    set -eu
    src="${homeDir}/.cache/dms/antigravity-theme.json"
    cfg="${homeDir}/.gemini/config/config.json"
    [ -f "$src" ] && [ -f "$cfg" ] || exit 0

    case "$(${jq} -r '.userSettings.themeMode' "$src")" in
      light) mode=THEME_MODE_LIGHT ;;
      dark) mode=THEME_MODE_DARK ;;
      *) mode=THEME_MODE_INHERIT ;;
    esac

    tmp="$(mktemp "$cfg.tmp.XXXXXX")"
    ${jq} -s --arg mode "$mode" '
      .[0].userSettings.customThemeSeedsDark = .[1].userSettings.customThemeSeedsDark
      | .[0].userSettings.customThemeSeedsLight = .[1].userSettings.customThemeSeedsLight
      | .[0].userSettings.themeMode = $mode
      | .[0]
    ' "$cfg" "$src" > "$tmp"
    cmp -s "$cfg" "$tmp" || cat "$tmp" > "$cfg"
    rm -f "$tmp"
  '';

  # [VS Code-family Editors]
  vscodeThemeSync = pkgs.writeShellScript "dms-vscode-theme-sync" ''
    set -eu
    mode="''${1:-dark}"
    [ "$mode" = "light" ] || mode="dark"
    cache="${homeDir}/.cache/dms/vscode"
    active_src="$cache/NoctaliaTheme-$mode.json"
    [ -f "$active_src" ] || exit 0

    for ext in \
      "${homeDir}"/.vscode/extensions/noctalia.noctaliatheme-* \
      "${homeDir}"/.antigravity/extensions/noctalia.noctaliatheme-*; do
      [ -f "$ext/package.json" ] || continue
      mkdir -p "$ext/themes"

      dst="$ext/themes/NoctaliaTheme-color-theme.json"
      tmp_theme="$(mktemp "$dst.XXXXXX")"
      ${pkgs.gnused}/bin/sed -E \
        's/"name": "Dynamic Base16 DankShell (Dark|Light)",/"name": "NoctaliaTheme",\n  "type": "'"$mode"'",/' \
        "$active_src" > "$tmp_theme"
      cmp -s "$dst" "$tmp_theme" || cat "$tmp_theme" > "$dst"
      rm -f "$tmp_theme"
    done
  '';
in
{
  # [Matugen Templates]
  xdg.configFile."matugen/config.toml".text = lib.mkAfter ''

    [templates.antigravity_color_scheme]
    input_path = "${antigravityTemplate}"
    output_path = "${homeDir}/.cache/dms/antigravity-theme.json"
    post_hook = "${antigravitySync} >/dev/null 2>&1 || true"

    [templates.vscode_noctalia_dark]
    input_path = "${dmsTemplates}/vscode-color-theme-dark.json"
    output_path = "${homeDir}/.cache/dms/vscode/NoctaliaTheme-dark.json"
    post_hook = "${vscodeThemeSync} {{ mode }} >/dev/null 2>&1 || true"

    [templates.vscode_noctalia_light]
    input_path = "${dmsTemplates}/vscode-color-theme-light.json"
    output_path = "${homeDir}/.cache/dms/vscode/NoctaliaTheme-light.json"
    post_hook = "${vscodeThemeSync} {{ mode }} >/dev/null 2>&1 || true"
  '';
}
