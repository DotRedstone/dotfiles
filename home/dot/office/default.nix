# ---
# Module: Office
# Description: Office suites and document tools
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    onlyoffice-bin
  ];
}
