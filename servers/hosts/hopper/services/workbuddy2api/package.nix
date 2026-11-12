# ---
# Module: Hopper WorkBuddy2API Package
# Description: Precompiled release packaging for workbuddy2api-panel
# Scope: Host
# ---

{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

let
  version = "2026.11.12.1729";
  sources = {
    aarch64-linux = {
      url = "https://github.com/misakano7545/workbuddy2api-panel/releases/download/v${version}/wb2api-panel-${version}-linux-arm64.zip";
      hash = "sha256-OuPI8vviOpoYWV42VD6f3/rVJ9EsS6ZfTUKxZFexH2s=";
    };
    x86_64-linux = {
      url = "https://github.com/misakano7545/workbuddy2api-panel/releases/download/v${version}/wb2api-panel-${version}-linux-amd64.zip";
      hash = "sha256-X2BSOnRk0OaFuF9KlHvCiPSWtfU0wLTmz0sBNYzz6Ss=";
    };
  };
  srcInfo = sources.${stdenv.hostPlatform.system}
    or (throw "workbuddy2api-panel 不支持当前平台: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "workbuddy2api-panel";
  inherit version;

  src = fetchurl {
    inherit (srcInfo) url hash;
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    unzip "$src"
  '';

  installPhase = ''
    mkdir -p "$out/bin" "$out/share/workbuddy2api"
    cp wb2api "$out/bin/wb2api"
    chmod +x "$out/bin/wb2api"
    cp config.example.json "$out/share/workbuddy2api/"
  '';

  meta = with lib; {
    description = "WorkBuddy / CodeBuddy OpenAI-compatible API gateway and management panel";
    homepage = "https://github.com/misakano7545/workbuddy2api-panel";
    mainProgram = "wb2api";
    platforms = [ "aarch64-linux" "x86_64-linux" ];
  };
}
