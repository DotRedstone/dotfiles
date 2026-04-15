# ---
# Module: Firefox Browser
# Description: Main Firefox profile with custom persistence and native messaging
# ---

{ config, pkgs, ... }: {
  imports = [
    ./settings.nix
    ./theme.nix
  ];

  # [Persistence Hack]
  # Force link to .mozilla to keep profile data safe across reboots
  home.file.".config/mozilla/firefox".source = 
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.mozilla/firefox";

  # [Native Messaging]
  # Required for Pywalfox to sync system colors with the browser
  home.file.".mozilla/native-messaging-hosts/pywalfox.json".text = builtins.toJSON {
    name = "pywalfox";
    description = "Pywalfox native messaging host";
    path = "${pkgs.pywalfox-native}/bin/pywalfox";
    type = "stdio";
    allowed_extensions = [ "pywalfox@frewacom.org" ];
  };

  # [Profile Definition]
  programs.firefox = {
    enable = true;
    profiles.dot = {
      id = 0;
      isDefault = true;
      name = "dot";
      
      # [Search Engine]
      search.force = true;
      search.default = "google";
      search.order = [ "google" ];
    };
  };
}
