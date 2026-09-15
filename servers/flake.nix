# ---
# Module: Server Flake Entry
# Description: Standalone entry point for declarative cloud server configurations
# Scope: Flake
# ---

{
  description = "dot's minimal NixOS server configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # GitHub's archive endpoint is unreliable on the current workstation link;
    # use the same upstream through a shallow Git fetch and pin it in flake.lock.
    hermes-agent.url = "git+https://github.com/NousResearch/hermes-agent.git?ref=main&shallow=1";
    hermes-agent.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      disko,
      hermes-agent,
      sops-nix,
      ...
    }:
    {
      nixosConfigurations = {
        conduit = nixpkgs.lib.nixosSystem {
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./hosts/conduit
          ];
        };

        gcp-free = nixpkgs.lib.nixosSystem {
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./hosts/gcp-free
          ];
        };

        hopper = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit hermes-agent; };
          modules = [
            disko.nixosModules.disko
            hermes-agent.nixosModules.default
            sops-nix.nixosModules.sops
            ./hosts/hopper
          ];
        };

        target = nixpkgs.lib.nixosSystem {
          modules = [
            sops-nix.nixosModules.sops
            ./hosts/target
          ];
        };
      };
    };
}
