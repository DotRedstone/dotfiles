# ---
# Module: 1Password
# Description: System integration for 1Password GUI and CLI
# Scope: System
# ---

{ ... }:

{
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "dot" ];
  };
}
