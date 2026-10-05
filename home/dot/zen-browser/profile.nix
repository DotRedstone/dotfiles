# ---
# Module: Zen Browser - Profile
# Description: Main Zen Browser profile definition and global settings
# Scope: Home Manager
# ---

{ pkgs, config, ... }: {
  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = [ pkgs.pywalfox-native ];
    profiles.dot = {
      id = 0;
      isDefault = true;
      name = "dot";
    };
  };

  # CLI wrapper so 'zen' command runs zen-beta
  home.packages = [
    (pkgs.writeShellScriptBin "zen" ''
      export MOZ_ENABLE_WAYLAND=1
      exec ${config.programs.zen-browser.finalPackage}/bin/zen-beta "$@"
    '')
  ];
}
