# ---
# Module: Niri Mac-style Shortcuts
# Description: Context-aware shortcuts for Niri
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  niri-mac-shortcut = pkgs.writeShellScriptBin "niri-mac-shortcut" ''
    # Get the app_id of the focused window
    APP_ID=$(niri msg --json focused-window 2>/dev/null | ${pkgs.jq}/bin/jq -r '.app_id // ""' 2>/dev/null || echo "")

    # Terminal detection
    is_terminal() {
      [[ "$APP_ID" == *"wezterm"* ]] || \
      [[ "$APP_ID" == "foot" ]] || \
      [[ "$APP_ID" == "alacritty" ]] || \
      [[ "$APP_ID" == "kitty" ]]
    }

    case "$1" in
      copy)
        if is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k c
        else
          ${pkgs.wtype}/bin/wtype -M ctrl -k c
        fi
        ;;
      paste)
        if is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k v
        else
          ${pkgs.wtype}/bin/wtype -M ctrl -k v
        fi
        ;;
      cut)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -k x
        fi
        ;;
      undo)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -k z
        fi
        ;;
      redo)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k z
        fi
        ;;
      select-all)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -k a
        fi
        ;;
      save)
        if ! is_terminal; then
          ${pkgs.wtype}/bin/wtype -M ctrl -k s
        fi
        ;;
      paste-plain)
        ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k v
        ;;
    esac
  '';
in
{
  home.packages = [ niri-mac-shortcut ];
}
