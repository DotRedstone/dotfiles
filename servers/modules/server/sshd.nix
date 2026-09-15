# ---
# Module: Server SSHD
# Description: Key-only SSH access for the administrative user
# Scope: System
# Notes:
# - Keep the firewall port synchronized if the SSH listen port changes.
# ---

{ ... }: {
  services.openssh = {
    enable = true;
    openFirewall = false;

    settings = {
      AllowUsers = [ "dot" ];
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };
}
