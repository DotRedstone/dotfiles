# ---
# Module: Chrome Policies
# Description: Managed Google Chrome defaults matching the Firefox profile
# ---

{ ... }:

{
  environment.etc."opt/chrome/policies/managed/warden.json".text = builtins.toJSON {
    RestoreOnStartup = 1;
    DefaultDownloadDirectory = "/home/dot/Downloads";
    PromptForDownloadLocation = false;
    PasswordManagerEnabled = false;
  };
}
