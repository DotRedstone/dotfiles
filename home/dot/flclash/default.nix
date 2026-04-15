# ---
# Module: FlClash
# Description: GUI Clash client with TUN mode support
# ---

{ pkgs, ... }: {
  # [Packages]
  home.packages = [ pkgs.flclash ];

  # [Note] 
  # Password-less TUN mode is handled at the system level 
  # in modules/system/network.nix
}
