# ---
# Module: Fcitx5 Global Config
# Description: Hotkeys and behavior settings
# Scope: Home Manager
# ---

# ---
# Module: Fcitx5 Config Entry
# Description: Main configuration generator for ~/.config/fcitx5/config
# ---

{ ... }:
let
  hotkeys = (import ./hotkeys.nix { }).hotkeys;
  behavior = (import ./behavior.nix { }).behavior;
in
{
  home.file.".config/fcitx5/config" = {
    force = true;
    text = ''
      ${hotkeys}
      ${behavior}
    '';
  };

  home.file.".config/fcitx5/profile" = {
    force = true;
    text = ''
      [Groups/0]
      # Group Name
      Name=默认
      # Layout
      Default Layout=us
      # Default Input Method
      DefaultIM=rime

      [Groups/0/Items/0]
      # Name
      Name=keyboard-us
      # Layout
      Layout=

      [Groups/0/Items/1]
      # Name
      Name=rime
      # Layout
      Layout=

      [GroupOrder]
      0=默认
    '';
  };
}
