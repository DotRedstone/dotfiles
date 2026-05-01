# ---
# Module: Steam Client Wrapper
# Description: User-level Steam launcher workaround for CEF rendering issues on Niri
# Scope: Home Manager
# ---

{ pkgs, lib, ... }:

let
  steamFlags = [
    "-cef-disable-gpu"
    "-cef-disable-gpu-compositing"
  ];

  # Wrapper script to launch Steam with CEF fallback flags
  steamWrapper = pkgs.writeShellScriptBin "steam" ''
    # Use the system path directly to avoid recursion with this wrapper
    exec /run/current-system/sw/bin/steam ${lib.escapeShellArgs steamFlags} "$@"
  '';
in {
  # Add the wrapper to the user's PATH
  home.packages = [
    steamWrapper
  ];

  # Override the desktop entry to ensure the GUI launcher uses the wrapper
  xdg.desktopEntries.steam = {
    name = "Steam";
    genericName = "Game client";
    comment = "Application for managing and playing games on Steam";
    exec = "steam %U";
    icon = "steam";
    terminal = false;
    categories = [ "Network" "FileTransfer" "Game" ];
    mimeType = [
      "x-scheme-handler/steam"
      "x-scheme-handler/steamlink"
    ];
    settings = {
      StartupWMClass = "steam";
    };
  };
}
