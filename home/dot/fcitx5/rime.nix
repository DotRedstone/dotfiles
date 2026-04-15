# ---
# Module: Rime Input Logic
# Description: Key bindings for candidate selection and first/last char commit
# ---

{ ... }: {
  # [Global Rime Settings]
  home.file.".local/share/fcitx5/rime/default.custom.yaml" = {
    force = true;
    text = ''
      patch:
        schema_list:
          - schema: rime_ice
        "menu/page_size": 10
        # Key bindings for selection
        "key_binder/bindings":
          - { when: has_menu, accept: Control_L, send: 2 }
          - { when: has_menu, accept: Control_R, send: 3 }
          - { when: has_menu, accept: bracketleft, send: "Control+Shift+1" }  # Select First Char
          - { when: has_menu, accept: bracketright, send: "Control+Shift+2" } # Select Last Char
    '';
  };

  # [Rime Ice Specific Patch]
  home.file.".local/share/fcitx5/rime/rime_ice.custom.yaml" = {
    force = true;
    text = ''
      patch:
        # --- ASCII / Chinese Switch ---
        "ascii_composer/good_old_caps_lock": true
        "ascii_composer/switch_key/Caps_Lock": clear
        "ascii_composer/switch_key/Shift_L": commit_code
        "ascii_composer/switch_key/Shift_R": commit_code
        "ascii_composer/switch_key/Control_L": noop
        "ascii_composer/switch_key/Control_R": noop
        
        # Disable uppercase patterns to prevent interference with Shift logic
        "recognizer/patterns/uppercase": ""
    '';
  };
}
