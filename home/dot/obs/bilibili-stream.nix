# ---
# Module: OBS Bilibili Stream Plugin
# Description: Builds the obs-bilibili-stream plugin from the upstream release source
# Scope: Home Manager
# ---

{
  lib,
  stdenv,
  fetchurl,
  cmake,
  ninja,
  pkg-config,
  obs-studio,
  qtbase,
  curl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "obs-bilibili-stream";
  version = "2.1.5";

  src = fetchurl {
    url = "https://github.com/Zarosmm/obs-bilibili-stream/releases/download/${finalAttrs.version}/bilibili-stream-for-obs-${finalAttrs.version}-source.tar.xz";
    hash = "sha256-Qv2nGfSp16egi5JU5Q96oHcNgaQ0RP2eFR9Onxa7oXg=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qtbase
  ];

  buildInputs = [
    obs-studio
    qtbase
    curl
  ];

  cmakeFlags = [
    (lib.cmakeBool "ENABLE_FRONTEND_API" true)
    (lib.cmakeBool "ENABLE_QT" true)
    # Upstream treats warnings as errors by default; Qt 6 emits deprecations
    # that are not actionable for a packaged build.
    (lib.cmakeBool "CMAKE_COMPILE_WARNING_AS_ERROR" false)
  ];

  # OBS hosts the plugin and already provides the Qt runtime; wrapping the
  # module separately would only add noise.
  dontWrapQtApps = true;

  # The plugin object and its resources are installed by the CMake helpers to
  # $out/lib/obs-plugins and $out/share/obs/obs-plugins, matching the layout
  # expected by nixpkgs' wrapOBS. Drop the redundant 64bit output tree.
  postInstall = ''
    rm -rf $out/obs-plugins
  '';

  meta = {
    description = "Bilibili live streaming plugin for OBS Studio";
    homepage = "https://github.com/Zarosmm/obs-bilibili-stream";
    changelog = "https://github.com/Zarosmm/obs-bilibili-stream/releases/tag/${finalAttrs.version}";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
})
