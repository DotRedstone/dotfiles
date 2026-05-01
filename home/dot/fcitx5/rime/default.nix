# ---
# Module: Rime Entry
# Description: Main entry point for Rime input method and schema management
# ---

{ lib, pkgs, ... }: {
  imports = [
    ./data.nix
    ./schema.nix
    ./lua
  ];

  home.file.".local/share/fcitx5/rime/rime_ice.custom.yaml".source =
    (pkgs.formats.yaml { }).generate "rime_ice.custom.yaml" {
      patch = import ./patches { inherit lib; };
    };
}
