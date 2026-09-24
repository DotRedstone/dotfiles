# ---
# Module: Rime Lua Select Character
# Description: Custom Lua function for selecting first and last characters via Ctrl or brackets
# Scope: Home Manager
# ---

{ ... }: {
  # Lua function to select character with Ctrl_L/Ctrl_R or [ and ]
  rime_lua = ''
    function select_character(key, env)
      if key:release() then
        return 2
      end

      local engine = env.engine
      local context = engine.context
      if not (context:is_composing() or context:has_menu()) then
        return 2
      end

      local k = key:repr()
      local kc = 0
      pcall(function() kc = key:keycode() end)

      local is_first = (k == "Control_L" or k == "Control+Control_L" or k == "bracketleft" or kc == 0xffe3 or kc == 0x5b)
      local is_last = (k == "Control_R" or k == "Control+Control_R" or k == "bracketright" or kc == 0xffe4 or kc == 0x5d)

      if is_first or is_last then
        local cand = context:get_selected_candidate()
        local text = cand and cand.text or context.input
        if text and #text > 0 then
          local char_to_commit
          if is_first then
            local offset = utf8.offset(text, 2)
            char_to_commit = offset and text:sub(1, offset - 1) or text
          else
            local offset = utf8.offset(text, -1)
            char_to_commit = offset and text:sub(offset) or text
          end

          if char_to_commit and #char_to_commit > 0 then
            engine:commit_text(char_to_commit)
            context:clear()
            return 1
          end
        end
      end
      return 2
    end
  '';
}

