# ---
# Module: Hopper DSH Remote Server Package
# Description: Wraps pinned upstream DSH Remote Server as a native Nix package
# Scope: Host
# ---

{
  stdenv,
  dockerTools,
  nodejs_22,
  makeWrapper,
  ...
}:

let
  img = dockerTools.pullImage {
    imageName = "ghcr.io/liguobao/ds-harness-remote/server";
    imageDigest = "sha256:8acf755fe5d350219d19839e44f8f8ab4037ed7ab5c7ff60dd196091ca0babb0";
    os = "linux";
    arch = "amd64";
    sha256 = "sha256-Pj7wSsmFyKdB11qoMB9fHEYpDADlwqL2p8sLd12yPJY=";
  };
in
stdenv.mkDerivation {
  pname = "dsh-remote-server";
  version = "0.6.3";
  src = img;

  nativeBuildInputs = [ makeWrapper ];

  phases = [ "unpackPhase" "installPhase" ];

  unpackPhase = ''
    tar -xf "$src"
    mkdir -p rootfs
    for layer in */layer.tar; do
      tar -xf "$layer" -C rootfs app 2>/dev/null || true
    done
  '';

  installPhase = ''
    mkdir -p "$out/libexec/dsh-remote-server" "$out/bin"
    cp -a rootfs/app/* "$out/libexec/dsh-remote-server/"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/dsh-remote-server" \
      --add-flags "$out/libexec/dsh-remote-server/dist/main.js"
  '';

  meta = {
    description = "Self-hosted DSH Remote Server relay service";
    mainProgram = "dsh-remote-server";
  };
}
