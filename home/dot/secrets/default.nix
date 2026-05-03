# ---
# Module: Secrets (Vault)
# Description: Redstone-grade encryption management
# ---

{ inputs, config, pkgs, ... }: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    
    defaultSopsFile = ../../../secrets.yaml; 

    secrets = {
      # Noctalia API Keys
      "gemini_api_key" = {
        sopsFile = ../../../secrets/noctalia.yaml;
      };
      "wallhaven_api_key" = {
        sopsFile = ../../../secrets/noctalia.yaml;
      };

      # VPS Info
      "vps/beacon" = {};
      "vps/conduit" = {};
      "vps/hopper" = {};
      "vps/target" = {};
      "vps/repeater" = {};
    };
  };
}
