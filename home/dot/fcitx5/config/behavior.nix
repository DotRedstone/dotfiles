# ---
# Module: Fcitx5 Behavior
# Description: General behavior settings like ShareInputState and CapsLock behavior
# Scope: Home Manager
# ---

{ ... }: {
  # Fcitx5 Behavior settings
  behavior = ''
    [Behavior]
    ActiveByDefault=True
    resetStateWhenFocusIn=No
    ShareInputState=All
    # Release Caps Lock to Rime for better ASCII/Chinese switching
    CapslockAction=None
  '';
}
