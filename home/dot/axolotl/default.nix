# ---
# Module: Axolotl Launcher
# Description: User-level installation of the Axolotl Minecraft launcher
# Scope: Home Manager
# ---

{ lib, pkgs, ... }:
let
  version = "1.9.5";
  runtimeLibraryPath = pkgs.lib.makeLibraryPath (with pkgs; [
    libayatana-appindicator
    libappindicator-gtk3
    libGL
    glfw
    glib
    openal
    libglvnd
    vulkan-loader
    libx11
    libxxf86vm
    libxext
    libxcursor
    libxkbcommon
    libxrandr
    libxtst
    libpulseaudio
    wayland
    alsa-lib
    gtk3

    # [CEF / MCEF Dependencies]
    nss
    nspr
    at-spi2-core
    cups
    libdrm
    cairo
    pango
    expat
    dbus
    libgbm
    libxcomposite
    libxdamage
    libxfixes
    libxcb
    stdenv.cc.cc.lib
    udev
    pciutils
    zlib
  ]);

  src = pkgs.fetchurl {
    url = "https://github.com/Mystic-Stars/Axolotl/releases/download/v${version}/Axolotl.Launcher_${version}_amd64.deb";
    sha256 = "0w39zkj8i92l633a0015pfpd7xq45qyql4j63vz0ny45r5d9wkc1";
  };

  axolotlLauncher = pkgs.stdenv.mkDerivation {
    pname = "axolotl-launcher";
    inherit version src;

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      dpkg
      makeWrapper
      wrapGAppsHook3
    ];

    buildInputs = with pkgs; [
      cairo
      dbus
      gdk-pixbuf
      glib
      glib-networking
      gtk3
      libayatana-appindicator
      libappindicator-gtk3
      libx11
      libxcb
      libsoup_3
      openssl
      webkitgtk_4_1
    ];

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x "$src" .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/lib" "$out/share"
      cp -r usr/lib/"Axolotl Launcher" "$out/lib/axolotl-launcher"
      install -Dm755 usr/bin/"Axolotl Launcher" "$out/lib/axolotl-launcher/axolotl-launcher"

      cp -r usr/share/* "$out/share/"
      mv "$out/share/applications/Axolotl Launcher.desktop" \
        $out/share/applications/axolotl-launcher.desktop

      substituteInPlace $out/share/applications/axolotl-launcher.desktop \
        --replace-fail 'Exec="Axolotl Launcher"' "Exec=axolotl-launcher" \
        --replace-fail "Icon=Axolotl Launcher" "Icon=axolotl-launcher"

      for size in 128x128 256x256@2; do
        icon="$out/share/icons/hicolor/$size/apps/Axolotl Launcher.png"
        if [ -f "$icon" ]; then
          mv "$icon" "$out/share/icons/hicolor/$size/apps/axolotl-launcher.png"
        fi
      done

      makeWrapper "$out/lib/axolotl-launcher/axolotl-launcher" "$out/bin/axolotl-launcher" \
        --chdir "$out/lib/axolotl-launcher" \
        --prefix LD_LIBRARY_PATH : "${runtimeLibraryPath}" \
        --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.temurin-bin-8 pkgs.temurin-bin-17 pkgs.temurin-bin-21 ]}" \
        --set WEBKIT_DISABLE_DMABUF_RENDERER 1

      runHook postInstall
    '';

    # wrapGAppsHook3 adds its wrapper during fixup, so game-specific variables
    # must be applied after that wrapper is in place.
    postFixup = ''
      wrapProgram "$out/bin/axolotl-launcher" \
        --set XDG_SESSION_TYPE x11 \
        --prefix JAVA_TOOL_OPTIONS ' ' "-Dorg.lwjgl.glfw.libname=${pkgs.glfw3-minecraft}/lib/libglfw.so.3.4"
    '';
  };

in
{
  home.packages = [ axolotlLauncher ];

  home.activation.patchMcefLibraries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mcef_dir="$HOME/.local/share/red.ghs.axolotl/profiles"
    if [ -d "$mcef_dir" ]; then
      ${pkgs.findutils}/bin/find "$mcef_dir" -type f \( -name "jcef_helper" -o -name "jcef_helper.real" -o -name "chrome-sandbox" \) -exec ${pkgs.patchelf}/bin/patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 {} + 2>/dev/null || true
    fi
  '';
}
