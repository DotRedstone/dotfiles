# ---
# Module: Go Development
# Description: Go toolchain, LSP, linter, debugger, and GOPATH environment
# Scope: Home Manager
# ---

{ config, pkgs, ... }:
let
  goPath = "${config.home.homeDirectory}/go";
in
{
  home.packages = with pkgs; [
    go
    gopls
    gotools
    golangci-lint
    delve
  ];

  home.sessionVariables = {
    GOPATH = goPath;
    GOBIN = "${goPath}/bin";
  };

  home.sessionPath = [
    "${goPath}/bin"
  ];
}
