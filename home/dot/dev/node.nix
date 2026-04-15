# ---
# Module: Node.js Ecosystem
# Description: Global pnpm; versions managed via project flakes & direnv
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    pnpm
  ];
}
