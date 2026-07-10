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

    # [Codex Desktop]
    codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";
    codex-desktop-linux.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, antigravity-nix, niri, ... }@inputs:
    let
      system = "x86_64-linux";
    in {

    # [System - nrs]
    nixosConfigurations.warden = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [ 
        ./hosts/warden 
        { nixpkgs.hostPlatform = system; }
      ];
    };

    # [Home - hms]
    homeConfigurations."dot@warden" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        localSystem = system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            python3 = prev.python3.override {
              packageOverrides = pyFinal: pyPrev: {
                "jedi-language-server" = pyPrev."jedi-language-server".overridePythonAttrs (old: {
                  pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "jedi" ];
                });
              };
            };
          })
          (final: prev: let
            activitywatchPackages = final.qt6Packages.callPackage (prev.path + "/pkgs/applications/office/activitywatch") {
              buildNpmPackage = args: prev.buildNpmPackage (args // final.lib.optionalAttrs ((args.pname or "") == "aw-webui") {
                doCheck = false;
              });
            };
          in {
            inherit (activitywatchPackages)
              aw-qt
              aw-notify
              aw-server-rust
              aw-watcher-afk
              aw-watcher-window;

            activitywatch = prev.activitywatch.override {
              inherit (activitywatchPackages)
                aw-qt
                aw-notify
                aw-server-rust
                aw-watcher-afk
                aw-watcher-window;
            };
          })
        ];
      };
      extraSpecialArgs = { inherit inputs; };
      modules = [ 
        ./home/dot 
        inputs.nixvim.homeModules.nixvim
      ];
    };
  };
}
