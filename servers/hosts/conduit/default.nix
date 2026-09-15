# ---
# Module: Conduit Host Entry
# Description: Declarative profile for the RackNerd Los Angeles edge node
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./disko.nix
    ./networking.nix
    ./platform.nix
    ./services.nix
    ../../modules/server
    ../../modules/services
  ];

  networking.hostName = "conduit";

  # Allow the administrative account to receive locally built closures over SSH.
  # This does not grant more authority than its existing passwordless sudo access.
  nix.settings.trusted-users = [ "dot" ];

  sops = {
    defaultSopsFile = ../../secrets/conduit.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  system.stateVersion = "26.05";
}
