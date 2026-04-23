# ---
# Module: Secrets (Vault)
# Description: Redstone-grade encryption management
# ---

{ inputs, config, ... }: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    
    defaultSopsFile = ../../../secrets.yaml; 

    secrets = {
      "vps/beacon" = {};
      "vps/conduit" = {};
      "vps/hopper" = {};
      "vps/target" = {};
      "vps/repeater" = {};
    };
  };
}
