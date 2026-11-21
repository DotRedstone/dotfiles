# ---
# Module: Server Flake Entry
# Description: Standalone entry point for declarative cloud server configurations
# Scope: Flake
# ---

{
  description = "dot's minimal NixOS server configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # ⚠️ 2026-11-21：只为了拿 nginx 1.30.7（CVE-2026-118899 / 123007）。
    # 整体升 nixpkgs 会牵动 hermes-agent / rustfs 在 ARM 上源码重编，撞 90 分钟超时；
    # 这个输入不 follows 主 nixpkgs，只用来取 nginxStable 这一个包。
    nixpkgs-nginx.url = "github:NixOS/nixpkgs/nixos-unstable";

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
    proxyStack.url = "git+https://github.com/DotRedstone/proxy-stack.git?ref=codex/reusable-release&rev=b5eef6670d0e2792beae65b31039503a83784db0";
    proxyStack.inputs.nixpkgs.follows = "nixpkgs";

    edgeProxyWorker = {
      url = "git+ssh://git@github.com/DotRedstone/edge-proxy-worker.git?ref=codex/public-speed-transition-20261018&rev=ad806d4f7f0737c8c079e91403620671b504f868";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-nginx,
      disko,
      hermes-agent,
      gmail-archiver,
      sops-nix,
      proxyStack,
      edgeProxyWorker,
      ...
    }:
    let
      mkConduit = privateModules: nixpkgs.lib.nixosSystem {
        specialArgs = { inherit proxyStack edgeProxyWorker; };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./hosts/conduit
        ] ++ privateModules;
      };
      mkHopper = privateModules: nixpkgs.lib.nixosSystem {
        specialArgs = { inherit hermes-agent proxyStack edgeProxyWorker; };
        modules = [
          disko.nixosModules.disko
          hermes-agent.nixosModules.default
          gmail-archiver.nixosModules.default
          sops-nix.nixosModules.sops
          ./hosts/hopper
          # 只把 nginx 换成新 nixpkgs 里的版本，其余包仍用主 nixpkgs，避免大包重编。
          ({ pkgs, ... }: {
            services.nginx.package =
              (import nixpkgs-nginx { system = pkgs.stdenv.hostPlatform.system; }).nginxStable;
          })
        ] ++ privateModules;
      };
    in
    {
      lib = { inherit mkConduit mkHopper; };
      packages = {
        x86_64-linux.proxyStackWorkerBundles = proxyStack.checks.x86_64-linux.workerBundles;
        aarch64-linux.proxyStackWorkerBundles = proxyStack.checks.aarch64-linux.workerBundles;
      };

      nixosConfigurations = {
        target = nixpkgs.lib.nixosSystem {
          specialArgs = { proxyStack = null; inherit edgeProxyWorker; };
          modules = [
            sops-nix.nixosModules.sops
            ./hosts/target
          ];
        };
      };
    };
}
