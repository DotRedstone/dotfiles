# ---
# Module: Network - SSHD
# Description: OpenSSH server configuration
# Scope: System
# ---

{ ... }: {
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      AllowUsers = [ "dot" "devguest" ];
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
