# ---
# Module: Rime Entry
# Description: Main entry point for Rime input method and schema management
# Scope: Home Manager
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

  home.activation.fcitx5RimeSyncPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sync_dir="$HOME/.local/share/fcitx5/rime/sync"
    if [ -d "$sync_dir" ]; then
      ${pkgs.findutils}/bin/find "$sync_dir" -type f -name '*.custom.yaml' -exec ${pkgs.coreutils}/bin/chmod u+w {} +
    fi
  '';

  home.activation.fcitx5RimeDeploy = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    rime_dir="$HOME/.local/share/fcitx5/rime"
    shared_dir="/tmp/rime-shared-$UID"
    rm -rf "$shared_dir"
    mkdir -p "$shared_dir"
    ln -sf ${pkgs.rime-data}/share/rime-data/* "$shared_dir/"
    ln -sf ${pkgs.rime-ice}/share/rime-data/* "$shared_dir/"
    ${pkgs.librime}/bin/rime_deployer --build "$rime_dir" "$shared_dir" "$rime_dir/build"
    rm -rf "$shared_dir"
    if ${pkgs.procps}/bin/pgrep -f fcitx5 >/dev/null 2>&1; then
      if [ -x /run/current-system/sw/bin/fcitx5 ]; then
        /run/current-system/sw/bin/fcitx5 -r -d >/dev/null 2>&1 || true
      fi
    fi
  '';
}
