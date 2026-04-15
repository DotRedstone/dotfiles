# ---
# Module: Kitty Terminal
# Description: Primary terminal emulator with Niri-optimized visuals
# ---

{
  programs.kitty.enable = true;

  imports = [
    ./font.nix
    ./theme.nix
  ];
}
