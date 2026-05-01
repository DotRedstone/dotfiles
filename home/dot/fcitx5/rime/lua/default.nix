# ---
# Module: Rime Lua Entry
# Description: Entry point for Rime Lua scripts (rime.lua)
# ---

{ ... }: {
  home.file.".local/share/fcitx5/rime/rime.lua".text = (import ./select-character.nix { }).rime_lua;
}
