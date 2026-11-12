# ---
# Module: Zen Browser - Native Messaging
# Description: External integrations for Zen Browser (Pywalfox)
# Scope: Home Manager
# ---

{ ... }: {

  home.file.".config/zen/native-messaging-hosts/com.1password.1password.json".text = builtins.toJSON {
    name = "com.1password.1password";
    description = "1Password BrowserSupport";
    path = "/run/wrappers/bin/1Password-BrowserSupport";
    type = "stdio";
    allowed_extensions = [
      "{0a75d802-9aed-41e7-8daa-24c067386e82}"
      "{25fc87fa-4d31-4fee-b5c1-c32a7844c063}"
      "{d634138d-c276-4fc8-924b-40a0ea21d284}"
    ];
  };
}
