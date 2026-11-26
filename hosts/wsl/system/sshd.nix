# ---
# Module: SSH Daemon
# Description: OpenSSH server listening on ports 22 and 520 for remote WSL access
# Scope: System
# ---

{ ... }: {
  services.openssh = {
    enable = true;
    ports = [ 22 520 ];
    openFirewall = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      PermitRootLogin = "no";
    };
  };
}
