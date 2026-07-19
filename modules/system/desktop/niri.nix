# ---
# Module: Desktop - Niri
# Description: Niri compositor system-level enablement
# Scope: System
# ---

{ pkgs, inputs, ... }:

let
  niriPackage = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri.overrideAttrs (old: {
    version = "${old.version or "unstable"}-shm-sharing";
    __intentionallyOverridingVersion = true;
    patches = (old.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        name = "niri-shm-sharing-f3207c77095114f9f2202ca7db8333d4c1a958d1.patch";
        url = "https://github.com/rucnyz/niri/commit/f3207c77095114f9f2202ca7db8333d4c1a958d1.patch";
        hash = "sha256-u7OEbVtePF21Phr8aTV0LZPFdDHu1Ju9Jnv+Sd33xDI=";
      })
    ];
  });
in
{
  programs.niri = {
    enable = true;
    package = niriPackage;
  };

  services.displayManager.defaultSession = "niri";
}
