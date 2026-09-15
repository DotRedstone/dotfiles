# ---
# Module: Hopper Host Entry
# Description: Declarative profile for the Oracle Cloud ARM application node
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./disko.nix
    ./networking.nix
    ./oci-platform.nix
    ./reverse-proxy.nix
    ./services.nix
    ./jupyterhub.nix
    ./hermes.nix
    ../../modules/server
    ../../modules/services
  ];

  networking.hostName = "hopper";

  nix.settings.trusted-users = [ "dot" ];

  # Preserve the Oracle-provisioned recovery key in addition to workstation keys.
  users.users.dot.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIz3aLIG8cKC7/086K4vK3SSYPlA7T7yZBQeh9CmpoNz"
  ];

  sops = {
    defaultSopsFile = ../../secrets/hopper.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  system.stateVersion = "26.05";
}
