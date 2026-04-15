# ---
# Module: Rime Input Logic
# Description: Key bindings for candidate selection and first/last char commit
# ---
{ pkgs, ... }: {
  home.file.".local/share/fcitx5/rime/lua" = {
    source = "${pkgs.rime-ice}/share/rime-data/lua";
    recursive = true;
    force = true;
  };

  home.file.".local/share/fcitx5/rime/rime.lua".text = ''
    function select_character(key, env)
      local engine = env.engine
      local context = engine.context
      local k = key:repr()
      if context:is_composing() and (k == "bracketleft" or k == "bracketright") then
        local cand = context:get_selected_candidate() or context:get_candidate_list():to_table()[1]
        if cand then
          local text = cand.text
          if k == "bracketleft" then
            engine:commit_text(text:sub(1, utf8.offset(text, 2) - 1))
          else
            engine:commit_text(text:sub(utf8.offset(text, utf8.len(text))))
          end
          context:clear()
          return 1
        end
      end
      return 2
    end
  '';

  home.file.".local/share/fcitx5/rime/default.custom.yaml".text = ''
    patch:
      schema_list: [{schema: rime_ice}]
      "menu/page_size": 10
  '';

  home.file.".local/share/fcitx5/rime/rime_ice.custom.yaml".text = ''
    patch:
      "ascii_composer/good_old_caps_lock": true
      "ascii_composer/switch_key/Caps_Lock": clear
      "ascii_composer/switch_key/Shift_L": commit_code
      "ascii_composer/switch_key/Shift_R": commit_code
      "key_binder/bindings":
        - { when: has_menu, accept: Control_L, send: 2 }
        - { when: has_menu, accept: Control_R, send: 3 }
      "engine/processors/@before 0": "lua_processor@select_character"
      "recognizer/patterns/uppercase": ""
  '';
}
