# ---
# Module: Zen Browser - Native Messaging
# Description: External integrations for Zen Browser (Pywalfox)
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = [ pkgs.pywalfox-native ];

  home.file.".config/zen/native-messaging-hosts/pywalfox.json".text = builtins.toJSON {
    name = "pywalfox";
    description = "Pywalfox native messaging host";
    path = "${pkgs.pywalfox-native}/bin/pywalfox";
    type = "stdio";
    allowed_extensions = [ "pywalfox@frewacom.org" ];
  };
}
