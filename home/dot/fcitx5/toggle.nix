# ---
# Module: Fcitx5 Input Method Toggle
# Description: Switches globally between the US keyboard and Rime engines
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  fcitx5-toggle-input = pkgs.writeShellApplication {
    name = "fcitx5-toggle-input";
    runtimeInputs = [ pkgs.fcitx5 ];
    text = ''
      # Let the focused Wayland client publish its latest caret rectangle
      # before Fcitx5 opens the input-method status popup.
      ${pkgs.coreutils}/bin/sleep 0.05

      current="$(${pkgs.fcitx5}/bin/fcitx5-remote -n 2>/dev/null || true)"

      case "$current" in
        rime)
          exec ${pkgs.fcitx5}/bin/fcitx5-remote -s keyboard-us
          ;;
        keyboard-us)
          exec ${pkgs.fcitx5}/bin/fcitx5-remote -s rime
          ;;
        *)
          exec ${pkgs.fcitx5}/bin/fcitx5-remote -s rime
          ;;
      esac
    '';
  };
in
{
  home.packages = [ fcitx5-toggle-input ];
}
