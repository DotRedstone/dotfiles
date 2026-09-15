# ---
# Module: GCP Free Host Entry
# Description: Declarative profile for the Google Cloud e2-micro proxy node
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./disko.nix
    ./google-compute.nix
    ./services.nix
    ../../modules/server
    ../../modules/services
  ];

  networking.hostName = "gcp-free";

  sops = {
    defaultSopsFile = ../../secrets/gcp-free.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  system.stateVersion = "26.05";
}
