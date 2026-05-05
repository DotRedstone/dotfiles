# ---
# Module: Google Antigravity AI Agent
# Description: AI-powered coding assistant from Google, integrated via flake package
# ---

{ inputs, pkgs, ... }:

let
  antigravity = inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-no-fhs;
in
{
  home.packages = [
    (pkgs.symlinkJoin {
      name = "google-antigravity-with-keyring";
      paths = [ antigravity ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        rm -f $out/bin/antigravity
        makeWrapper ${antigravity}/bin/antigravity $out/bin/antigravity \
          --add-flags "--password-store=gnome-libsecret"
      '';
    })
  ];
}
