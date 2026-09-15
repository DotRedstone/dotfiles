# ---
# Module: Target Host Entry
# Description: Declarative profile for the domestic EasyTier relay and game forwarder
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./services.nix
    ../../modules/server
    ../../modules/services
  ];

  networking.hostName = "target";
  nix.settings.trusted-users = [ "dot" ];

  sops = {
    defaultSopsFile = ../../secrets/target.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  system.stateVersion = "26.05";
}
