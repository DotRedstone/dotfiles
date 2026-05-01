# ---
# Module: Flake Entry
# Description: Main entry point for NixOS (warden) and Home Manager (dot) configurations
# Scope: Flake
# ---

{
  description = "dot's Warden NixOS configuration";

  inputs = {
    # [Core]
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # [Persistence]
    impermanence.url = "github:nix-community/impermanence";

    # [Desktop]
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    silent-sddm.url = "github:uiriansan/SilentSDDM";
    silent-sddm.inputs.nixpkgs.follows = "nixpkgs";
    niri.url = "github:YaLTeR/niri";
    niri.inputs.nixpkgs.follows = "nixpkgs";

    # [Editor]
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    # [Security]
    sops-nix.url = "github:Mic92/sops-nix";

    # [Antigravity]
    antigravity-nix.url = "github:jacopone/antigravity-nix";
    antigravity-nix.inputs.nixpkgs.follows = "nixpkgs"; 
  };

  outputs = { self, nixpkgs, home-manager, antigravity-nix, niri, ... }@inputs:
    let
      system = "x86_64-linux";
    in {

    # [System - nrs]
    nixosConfigurations.warden = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [ ./hosts/warden ];
    };

    # [Home - hms]
    homeConfigurations."dot@warden" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = { inherit inputs; };
      modules = [ 
        ./home/dot 
        inputs.nixvim.homeModules.nixvim
      ];
    };
  };
}
