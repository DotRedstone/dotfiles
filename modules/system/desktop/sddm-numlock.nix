# ---
# Module: Desktop - SDDM NumLock
# Description: Workaround for SDDM Wayland/KWin NumLock state persistence
# Scope: System
# ---

{ pkgs, ... }:

let
  sddmStateDir = "/var/lib/sddm";

  sddmKcminputrc = pkgs.writeText "sddm-kcminputrc" ''
    [Keyboard]
    NumLock=0
  '';

  sddmKwinrc = pkgs.writeText "sddm-kwinrc" ''
    [Keyboard]
    NumLock=0
  '';
in {
  # SDDM's NixOS autoNumlock option writes General/Numlock=on into sddm.conf,
  # which is enough for the X11 greeter path. The Wayland greeter starts KWin
  # as the sddm user instead, and KWin initializes keyboard state from that
  # user's KDE config in $HOME/.config. NixOS creates the sddm home at
  # /var/lib/sddm, so seed the same NumLock preference there before the greeter
  # starts. In KDE's keyboard config, NumLock=0 means "turn NumLock on".
  systemd.tmpfiles.rules = [
    "d ${sddmStateDir} 0755 sddm sddm -"
    "d ${sddmStateDir}/.config 0750 sddm sddm -"
    "C+ ${sddmStateDir}/.config/kcminputrc 0644 sddm sddm - ${sddmKcminputrc}"
    "C+ ${sddmStateDir}/.config/kwinrc 0644 sddm sddm - ${sddmKwinrc}"
    "z ${sddmStateDir} 0755 sddm sddm -"
    "z ${sddmStateDir}/.config 0750 sddm sddm -"
    "z ${sddmStateDir}/.config/kcminputrc 0644 sddm sddm -"
    "z ${sddmStateDir}/.config/kwinrc 0644 sddm sddm -"
  ];

  systemd.services.display-manager = {
    # tmpfiles runs during activation, but an already persisted /var/lib/sddm can
    # keep stale ownership. Reinstall these files immediately before SDDM starts
    # so KWin reads the NumLock config from an sddm-owned HOME every boot.
    preStart = ''
      ${pkgs.coreutils}/bin/install -d -o sddm -g sddm -m 0755 ${sddmStateDir}
      ${pkgs.coreutils}/bin/install -d -o sddm -g sddm -m 0750 ${sddmStateDir}/.config
      ${pkgs.coreutils}/bin/install -o sddm -g sddm -m 0644 ${sddmKcminputrc} ${sddmStateDir}/.config/kcminputrc
      ${pkgs.coreutils}/bin/install -o sddm -g sddm -m 0644 ${sddmKwinrc} ${sddmStateDir}/.config/kwinrc
    '';
  };
}
