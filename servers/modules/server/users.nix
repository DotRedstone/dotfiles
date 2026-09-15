# ---
# Module: Server Users
# Description: Locked-password administrative account with SSH key and sudo access
# Scope: System
# Notes:
# - Passwordless sudo is required because the account intentionally has no password.
# - Replace or extend the public key list before revoking the current workstation key.
# ---

{ ... }: {
  users = {
    mutableUsers = false;

    users = {
      root.hashedPassword = "!";

      dot = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        hashedPassword = "!";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN7z2cUJ5ey++XGnKwtsxaox8x9XZmLwb7QwSdg0gWsP dot@beacon"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPpF2qZUXdWDFZogBMSTEHJNmUwOdFnPkHZzLexVT06K dot@warden"
        ];
      };
    };
  };

  security.sudo.wheelNeedsPassword = false;
}
