# ---
# Module: Beacon Networking
# Description: Host identity, SSH authorized keys, and remote login enablement
# Scope: Host
# ---

{ ... }:

{
  # [Host Identity]
  networking = {
    hostName = "beacon";
    computerName = "beacon";
    localHostName = "beacon";
  };

  # [User & Authorized Keys]
  users.users.dot = {
    name = "dot";
    home = "/Users/dot";
    openssh.authorizedKeys.keys = [
      # Warden workstation primary key
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPpF2qZUXdWDFZogBMSTEHJNmUwOdFnPkHZzLexVT06K dot@warden"
      # Secondary workstation / recovery key
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIz3aLIG8cKC7/086K4vK3SSYPlA7T7yZBQeh9CmpoNz"
    ];
  };

  # [Remote Login Activation]
  # Ensures macOS remote login (sshd) is turned on.
  system.activationScripts.enableRemoteLogin.text = ''
    echo "[Networking] Ensuring remote login (SSH) is enabled..."
    /usr/sbin/systemsetup -f -setremotelogin on 2>/dev/null || true
  '';
}
