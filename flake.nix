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
    noctalia-mihomo-control = {
      url = "github:DotRedstone/noctalia-mihomo-control/v0.1.0";
      flake = false;
    };
    noctalia-media-lyrics = {
      url = "github:DotRedstone/noctalia-media-lyrics/v1.3.4";
      flake = false;
    };
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

    # [Zen Browser]
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    zen-browser.inputs.home-manager.follows = "home-manager";

    # [Claude Desktop]
    claude-desktop-linux.url = "github:k3d3/claude-desktop-linux-flake";

    # [Darwin]
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
          # mitmproxy 的 TLS 证书测试依赖外部信任链，在本机沙箱内必然失败。
          (final: prev: {
            mitmproxy = prev.mitmproxy.overridePythonAttrs (old: {
              doCheck = false;
            });
          })
        ];
      };
      extraSpecialArgs = { inherit inputs; };
      modules = [ 
        ./home/dot 
        inputs.nixvim.homeModules.nixvim
        inputs.zen-browser.homeModules.default
      ];
    };

    # [Darwin - beacon (Mac mini headless)]
    darwinConfigurations.beacon = inputs.darwin.lib.darwinSystem {
      modules = [
        ./hosts/beacon
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.dot = import ./hosts/beacon/home.nix;
        }
      ];
      specialArgs = { inherit inputs; };
    };

    # [DevShell - PixelOS 编译环境]
    # AOSP 构建系统（soong/envsetup）依赖 /bin/sh、/usr/lib 等 FHS 路径，
    # 必须用 buildFHSEnv 包裹，否则在 NixOS 上会因找不到标准路径而崩。
    devShells.x86_64-linux.pixelos = let
      pkgs = import nixpkgs {
        localSystem = system;
        config.allowUnfree = true;
      };
      # AOSP 的构建脚本直接调用 python（PEP394 下 nix 的 python312 只提供 python3），
      # 这里补一个 python -> python3 别名。
      pythonWithAlias = pkgs.runCommand "python-with-alias" { } ''
        mkdir -p "$out/bin"
        ln -s "${pkgs.python312}/bin/python3" "$out/bin/python"
      '';
    in pkgs.buildFHSEnv {
      name = "pixelos-build";
      targetPkgs = p: with p; [
        # [工具链]
        git
        git-lfs
        git-repo
        python312
        pythonWithAlias
        jdk17
        gnumake
        gcc
        binutils
        bison
        flex
        gperf
        zip
        unzip
        rsync
        bc
        curl
        ccache
        cpio
        file
        which
        perl
        patchelf
        # [库]
        openssl
        elfutils
        ncurses
        libxml2
        libxslt
        zlib
        lz4
        readline
        # [Android 16 额外：aconfig/protobuf]
        protobuf
      ];
      multiPkgs = p: [ p.glibc_multi ];
      runScript = "bash";
    };
  };
}
