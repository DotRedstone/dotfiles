# ---
# Module: Kitty Terminal
# Description: Primary terminal emulator with Niri-optimized visuals
# Scope: Home Manager
# ---

{
  programs.kitty.enable = true;

  imports = [
    ./font.nix
    ./theme.nix
  ];
}
