# ---
# Module: PicList
# Description: Cloud storage and image hosting manager based on PicGo
# Scope: Home Manager
# ---

{ pkgs, lib, ... }:

let
  version = "3.3.2";
  pname = "piclist";

  src = pkgs.fetchurl {
    url = "https://github.com/Kuingsmile/PicList/releases/download/v${version}/PicList-${version}-amd64.deb";
    hash = "sha256-QD0a3EtJX1dHpJPm2+Foc7hq+FpGtXhngEfDqSuZAoY=";
  };
in
{
  home.packages = [
    (pkgs.stdenv.mkDerivation {
      inherit pname version src;

      nativeBuildInputs = [
        pkgs.autoPatchelfHook
        pkgs.dpkg
        pkgs.makeWrapper
      ];

      buildInputs = with pkgs; [
        alsa-lib
        at-spi2-atk
        atk
        cairo
        cups
        dbus
        expat
        fontconfig
        freetype
        gdk-pixbuf
        glib
        gtk3
        libGL
        libX11
        libXScrnSaver
        libXcomposite
        libXcursor
        libXdamage
        libXext
        libXfixes
        libXi
        libXrandr
        libXrender
        libXtst
        libdrm
        libnotify
        libpulseaudio
        libuuid
        libxcb
        libxkbcommon
        mesa
        musl
        nspr
        nss
        pango
        systemd
      ];

      unpackPhase = "dpkg-deb -x $src .";

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/opt/piclist
        cp -r opt/PicList/* $out/opt/piclist/
        
        # Fix the desktop file and icons
        mkdir -p $out/share
        cp -r usr/share/* $out/share/
        
        # Rename and patch desktop file
        if [ -f $out/share/applications/PicList.desktop ]; then
          mv $out/share/applications/PicList.desktop $out/share/applications/piclist.desktop
          substituteInPlace $out/share/applications/piclist.desktop \
            --replace "/opt/PicList/PicList" "piclist" \
            --replace "Icon=PicList" "Icon=piclist"
        fi
          
        # Rename icon
        if [ -f $out/share/icons/hicolor/512x512/apps/PicList.png ]; then
          mv $out/share/icons/hicolor/512x512/apps/PicList.png $out/share/icons/hicolor/512x512/apps/piclist.png
        fi

        # Create wrapper
        makeWrapper $out/opt/piclist/PicList $out/bin/piclist \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath (with pkgs; [
            alsa-lib
            at-spi2-atk
            atk
            cairo
            cups
            dbus
            expat
            fontconfig
            freetype
            gdk-pixbuf
            glib
            gtk3
            libGL
            libX11
            libXScrnSaver
            libXcomposite
            libXcursor
            libXdamage
            libXext
            libXfixes
            libXi
            libXrandr
            libXrender
            libXtst
            libdrm
            libnotify
            libpulseaudio
            libuuid
            libxcb
            libxkbcommon
            mesa
            musl
            nspr
            nss
            pango
            systemd
          ])}" \
          --add-flags "--no-sandbox"

        runHook postInstall
      '';

      meta = with lib; {
        description = "Cloud storage and image hosting manager based on PicGo";
        homepage = "https://github.com/Kuingsmile/PicList";
        license = licenses.mit;
        platforms = [ "x86_64-linux" ];
        mainProgram = "piclist";
      };
    })
  ];
}
