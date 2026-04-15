# ---
# Module: Fcitx5 Global Config
# Description: Hotkeys and behavior settings
# ---

{ ... }: {
  home.file.".config/fcitx5/config" = {
    force = true;
    text = ''
      [Hotkey]
      TriggerKeys=
      AltTriggerKeys=
      EnumerateForwardKeys=
      EnumerateBackwardKeys=
      EnumerateSkipFirstKeys=

      [Hotkey/TriggerKeys]
      0=Super+space

      [Behavior]
      ActiveByDefault=False
      ShareInputState=No
      # Release Caps Lock to Rime for better ASCII/Chinese switching
      CapslockAction=None
    '';
  };
}
