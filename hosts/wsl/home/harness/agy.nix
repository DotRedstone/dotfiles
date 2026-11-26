# ---
# Module: Antigravity CLI
# Description: Official Antigravity terminal CLI (agy)
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  agyCli = pkgs.stdenv.mkDerivation {
    pname = "antigravity-cli";
    version = "1.5.17";

    src = pkgs.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.5.17-4823843970351104/linux-x64/cli_linux_x64.tar.gz";
      hash = "sha512-calnqhbgq12HGWvNZ3ITC9q1Wy/XaM0k0hsdpAH/n2AoC5dsrT3BSi1kYjOw6vjK+HxJDu1zBE1UVQy7PY1n0g==";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      mkdir -p work "$out/bin"
      tar -xzf "$src" -C work
      bin=$(find work -maxdepth 2 -type f | head -n 1)
      install -m755 "$bin" "$out/bin/agy"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Google Antigravity terminal CLI";
      homepage = "https://antigravity.google";
      platforms = [ "x86_64-linux" ];
      mainProgram = "agy";
    };
  };
in {
  home.packages = [ agyCli ];
}
