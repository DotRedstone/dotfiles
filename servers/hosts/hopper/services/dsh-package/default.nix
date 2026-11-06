# ---
# Module: Hopper DSH Runtime Package
# Description: Wraps the pinned DeepSeek Harness npm CLI as a native Nix package
# Scope: Host
# Notes:
# - Version and package-lock are blocked until the user selects an exact release.
# - Replace lib.fakeHash only after generating and reviewing dependency integrity.
# ---

{ lib, buildNpmPackage, nodejs_24, makeWrapper, python3, pkg-config }:
let
  npmDepsHash = lib.fakeHash;
  manifest = builtins.fromJSON (builtins.readFile ./package.json);
  lockPresent = builtins.pathExists ./package-lock.json;
  lock = if lockPresent then builtins.fromJSON (builtins.readFile ./package-lock.json) else {};
  manifestVersion = lib.attrByPath [ "dependencies" "@deepseek-ai/dsh" ] null manifest;
  lockDeclaredVersion = lib.attrByPath [ "packages" "" "dependencies" "@deepseek-ai/dsh" ] null lock;
  packageVersion = lib.attrByPath [ "packages" "node_modules/@deepseek-ai/dsh" "version" ] null lock;
  packageResolved = lib.attrByPath [ "packages" "node_modules/@deepseek-ai/dsh" "resolved" ] null lock;
  packageIntegrity = lib.attrByPath [ "packages" "node_modules/@deepseek-ai/dsh" "integrity" ] null lock;
in
buildNpmPackage {
  pname = "hopper-dsh-runtime";
  version = "1.0.0";
  src = lib.cleanSource ./.;
  nodejs = nodejs_24;
  inherit npmDepsHash;
  passthru = {
    packageLockPresent = lockPresent;
    packageManifestVersion = manifestVersion;
    packageLockDeclaredVersion = lockDeclaredVersion;
    packageLockVersion = packageVersion;
    packageLockResolved = packageResolved;
    packageLockIntegrity = packageIntegrity;
  };
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper python3 pkg-config ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/dsh" "$out/bin"
    cp package.json package-lock.json "$out/libexec/dsh/"
    cp -a node_modules "$out/libexec/dsh/"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/dsh" \
      --add-flags "$out/libexec/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js"
    runHook postInstall
  '';
  meta = {
    description = "Nix-packaged DeepSeek Harness CLI for Hopper";
    mainProgram = "dsh";
    platforms = lib.platforms.linux;
  };
}
