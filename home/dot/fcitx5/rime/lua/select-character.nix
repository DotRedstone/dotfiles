# ---
# Module: Rime Lua Select Character
# Description: Custom Lua processor for bracket-based character picking and Ctrl-based candidate selection
# Scope: Home Manager
# ---

{ ... }: {
  # [Handler]
  rime_lua = ''
    function select_character(key, env)
      if key:release() then
        return 2
      end

      local engine = env.engine
      local context = engine.context
      if context:get_option("ascii_mode") or not (context:is_composing() or context:has_menu()) then
        return 2
      end

      local k = key:repr()
      local kc = 0
      pcall(function() kc = key:keycode() end)

      -- [Character Selection]
      local is_bracket_left = (not (key:ctrl() or key:alt() or key:super())) and (k == "bracketleft" or kc == 0x5b)
      local is_bracket_right = (not (key:ctrl() or key:alt() or key:super())) and (k == "bracketright" or kc == 0x5d)

      if is_bracket_left or is_bracket_right then
        local cand = context:get_selected_candidate()
        if not cand and context.composition:has_menu() then
          pcall(function()
            local seg = context.composition:back()
            cand = seg and seg:get_candidate_at(0)
          end)
        end

        local text = cand and cand.text or context.input
        if text and #text > 0 then
          local char_to_commit
          if is_bracket_left then
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
        return 2
      end

      -- [Candidate Selection]
      local is_ctrl_l = (not (key:alt() or key:super())) and (k == "Control_L" or k == "Control+Control_L" or kc == 0xffe3)
      local is_ctrl_r = (not (key:alt() or key:super())) and (k == "Control_R" or k == "Control+Control_R" or kc == 0xffe4)

      if (is_ctrl_l or is_ctrl_r) and context:has_menu() then
        local page_size = 5
        pcall(function()
          local s = engine.schema
          if s then
            if type(s.page_size) == "function" then
              page_size = s:page_size()
            elseif type(s.page_size) == "number" then
              page_size = s.page_size
            end
          end
        end)

        local seg
        pcall(function() seg = context.composition:back() end)
        if not seg then
          return 2
        end

        local selected_index = seg.selected_index or 0
        local page_start = selected_index - (selected_index % page_size)
        local target_index = page_start + (is_ctrl_l and 1 or 2)

        local cand
        pcall(function() cand = seg:get_candidate_at(target_index) end)
        if cand then
          local ok = false
          pcall(function() ok = context:select(target_index) end)
          if ok then
            return 1
          else
            engine:commit_text(cand.text)
            context:clear()
            return 1
          end
        end
      end

      return 2
    end
  '';
}

