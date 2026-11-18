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
  version = "2026.11.18.1058";
  sources = {
    aarch64-linux = {
      url = "https://github.com/misakano7545/workbuddy2api-panel/releases/download/v${version}/wb2api-panel-${version}-linux-arm64.zip";
      hash = "sha256-G15lwu0yfOupUPvztgPMNqDkSK4kru5+qr6jlN3G++w=";
    };
    x86_64-linux = {
      url = "https://github.com/misakano7545/workbuddy2api-panel/releases/download/v${version}/wb2api-panel-${version}-linux-amd64.zip";
      hash = "sha256-bcrj4D9vuwfREkHd9fiDMRY+2Q0LIbdJO4XcNEgwEjo=";
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
