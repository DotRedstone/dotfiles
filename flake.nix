# ---
# Module: Flake Entry
# Description: Main entry point for Warden (NixOS) and Beacon (macOS)
# ---

{
  description = "dot's Flake configuration for NixOS and macOS";

  inputs = {
    # [Core]
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # [macOS]
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # [Persistence]
    impermanence.url = "github:nix-community/impermanence";

    # [Desktop]
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    silent-sddm.url = "github:uiriansan/SilentSDDM";
    silent-sddm.inputs.nixpkgs.follows = "nixpkgs";

    # [Editor]
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";
    in {

    # [System - NixOS]
    nixosConfigurations.warden = nixpkgs.lib.nixosSystem {
      system = linuxSystem;
      specialArgs = { inherit inputs; };
      modules = [ ./hosts/warden ];
    };

    # [System - macOS]
    darwinConfigurations.beacon = darwin.lib.darwinSystem {
      system = darwinSystem;
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/beacon
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.dot = import ./home/dot/mac.nix;
        }
      ];
    };

    # [Home - Standalone Linux]
    homeConfigurations."dot@warden" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = linuxSystem;
        config.allowUnfree = true;
      };
      extraSpecialArgs = { inherit inputs; };
      modules = [ ./home/dot ];
    };
  };
}
