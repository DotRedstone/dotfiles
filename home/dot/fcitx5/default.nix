# ---
# Module: Fcitx5 Entry
# Description: Unified entry point for Fcitx5 environment, config, Rime, and themes
# ---

{ ... }: {
  imports = [
    ./env.nix
    ./config
    ./rime
    ./theme.nix
  ];
}
