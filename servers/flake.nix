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

    gmail-archiver.url = "github:DotRedstone/gmail-archiver";
    gmail-archiver.inputs.nixpkgs.follows = "nixpkgs";

    # Private remote is fetched at one exact revision from flake.lock.
    proxyStack.url = "git+https://github.com/DotRedstone/proxy-stack.git?ref=main";
    proxyStack.inputs.nixpkgs.follows = "nixpkgs";

    edgeProxyWorker = {
      url = "git+ssh://git@github.com/DotRedstone/edge-proxy-worker.git?ref=main";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      hermes-agent,
      gmail-archiver,
      sops-nix,
      proxyStack,
      edgeProxyWorker,
      ...
    }:
    {
      packages = {
        x86_64-linux.proxyStackWorkerBundles = proxyStack.checks.x86_64-linux.workerBundles;
        aarch64-linux.proxyStackWorkerBundles = proxyStack.checks.aarch64-linux.workerBundles;
      };

      nixosConfigurations = {
        conduit = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit proxyStack; };
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./hosts/conduit
          ];
        };

        gcp-free = nixpkgs.lib.nixosSystem {
          specialArgs = { proxyStack = null; };
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./hosts/gcp-free
          ];
        };

        hopper = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit hermes-agent proxyStack; };
          modules = [
            disko.nixosModules.disko
            hermes-agent.nixosModules.default
            gmail-archiver.nixosModules.default
            sops-nix.nixosModules.sops
            ./hosts/hopper
          ];
        };

        target = nixpkgs.lib.nixosSystem {
          specialArgs = { proxyStack = null; inherit edgeProxyWorker; };
          modules = [
            sops-nix.nixosModules.sops
            ./hosts/target
            ./hosts/target/probe-source.nix
            ./hosts/target/probe-tls.nix
          ];
        };
      };
    };
}
