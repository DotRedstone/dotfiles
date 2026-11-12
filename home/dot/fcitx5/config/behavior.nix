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
    # 禁用 DBus 虚拟键盘：触屏设备用不上，且其 CandidateList::toBulk 曾导致 SIGSEGV
    # （见 ~/.config/fcitx5/crash.log，2026-07-29）。
    # DisabledAddons 是 vector<string>，fcitx5 用子配置索引序列化（0/1/...），
    # 不是逗号分隔；单元素因此写成 [Behavior/DisabledAddons] 下的 0=...。
    [Behavior/DisabledAddons]
    0=virtualkeyboard
  '';
}
