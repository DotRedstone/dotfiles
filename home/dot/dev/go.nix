# ---
# Module: Go Development
# Description: Go compiler, language server, debugger, and tooling for Warden
# Scope: Home Manager
# ---

{ config, pkgs, ... }:
let
  goPath = "${config.home.homeDirectory}/go";
in
{
  # [Packages]
  home.packages = with pkgs; [
    # [Compiler]
    go

    # [LSP & Tooling]
    gopls
    gotools
    golangci-lint

    # [Debugger]
    delve
  ];

  # [Environment]
  home.sessionVariables = {
    GOPATH = goPath;
    GOBIN = "${goPath}/bin";
  };

  # [Path]
  home.sessionPath = [
    "${goPath}/bin"
  ];
}
