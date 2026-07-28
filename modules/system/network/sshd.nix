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
      PasswordAuthentication = true; # default to true for local usability
      PermitRootLogin = "no";
    };
  };
}
