# ---
# Module: Clavis Shell
# Description: Package StatIndet Clavis Shell, key-cli, and qt6-m3shapes with on-demand user services
# Scope: Home Manager
# ---
# Notes:
# - Intentionally omits Install.WantedBy so Clavis does not conflict with noctalia.service on login.
# - Switch to Clavis at runtime via `desktop-shell clavis`.

{ pkgs, lib, ... }:
let
  mkQmlImportPath = qmlPkgs:
    lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtQmlPrefix}") qmlPkgs);

  mkQtPluginPath = qtPkgs:
    lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtPluginPrefix}") qtPkgs);

  # [M3Shapes QML Module]
  qt6-m3shapes = pkgs.stdenv.mkDerivation {
    pname = "qt6-m3shapes";
    version = "1.0.0-git-8a6fe89";
    src = pkgs.fetchFromGitHub {
      owner = "soramanew";
      repo = "m3shapes";
      rev = "8a6fe8961749887d677700b6508e0c9249968b7e";
      hash = "sha256-VsztSn0D8sxAFNcwnHCCR3lNf8+3qgcHiYurgYhsKcE=";
    };
    nativeBuildInputs = [
      pkgs.cmake
      pkgs.ninja
      pkgs.qt6.wrapQtAppsHook
      pkgs.qt6.qtshadertools
    ];
    buildInputs = [
      pkgs.qt6.qtbase
      pkgs.qt6.qtdeclarative
    ];
    dontWrapQtApps = true;
    cmakeFlags = [
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DINSTALL_QMLDIR=${pkgs.qt6.qtbase.qtQmlPrefix}"
    ];
  };

  # [Clavis Shell Core & Config]
  clavis-shell = pkgs.stdenv.mkDerivation rec {
    pname = "clavis-shell";
    version = "2026.9.25";
    src = pkgs.fetchurl {
      url = "https://github.com/StatIndet/quickshell/releases/download/v${version}/clavis-shell-${version}.tar.gz";
      hash = "sha256-PCk0GleoMJ5wJAiR4zgXg/AZKDJdgavKqOxkESpVcqw=";
    };
    nativeBuildInputs = [
      pkgs.cmake
      pkgs.ninja
      pkgs.pkg-config
      pkgs.python3
      pkgs.wayland-scanner
      pkgs.qt6.qttools
      pkgs.qt6.qtshadertools
    ];
    buildInputs = [
      pkgs.qt6.qtbase
      pkgs.qt6.qtdeclarative
      pkgs.qt6.qtwayland
      pkgs.kdePackages.qtkeychain
      pkgs.systemd
      pkgs.pipewire
      pkgs.libcava
      pkgs.libxkbcommon
      pkgs.wayland
      pkgs.wayland-protocols
      pkgs.glib
      pkgs.libsysprof-capture
    ];
    dontWrapQtApps = true;
    preConfigure = ''
      chmod -R u+w .
    '';
    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DBUILD_TESTING=OFF"
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCLAVIS_QML_INSTALL_DIR=${placeholder "out"}/${pkgs.qt6.qtbase.qtQmlPrefix}"
      "-DCLAVIS_CONFIG_INSTALL_DIR=${placeholder "out"}/etc/xdg/quickshell/clavis"
    ];
    postInstall = ''
      rm -rf $out/lib/systemd $out/share/systemd
      for f in $out/${pkgs.qt6.qtbase.qtQmlPrefix}/Clavis/*/*.so; do
        dir=$(dirname "$f")
        rpath=$(${pkgs.patchelf}/bin/patchelf --print-rpath "$f" | tr ':' '\n' | grep -v '^/build' | paste -sd: -)
        ${pkgs.patchelf}/bin/patchelf --set-rpath "$dir:$rpath" "$f"
      done
    '';
  };

  clavisQtPackages = [
    clavis-shell
    qt6-m3shapes
    pkgs.qt6.qtbase
    pkgs.qt6.qtdeclarative
    pkgs.qt6.qt5compat
    pkgs.qt6.qtlottie
    pkgs.qt6.qtlocation
    pkgs.qt6.qtpositioning
    pkgs.qt6.qtsvg
    pkgs.qt6.qtwayland
    pkgs.qt6.qtmultimedia
    pkgs.quickshell
  ];

  clavisRuntimeBins = [
    pkgs.quickshell
    pkgs.matugen
    pkgs.jq
    pkgs.fd
    pkgs.wl-clipboard
    pkgs.cliphist
    pkgs.glib
    pkgs.libqalculate
    pkgs.gpu-screen-recorder
    pkgs.ffmpeg
    pkgs.pulseaudio
    pkgs.slurp
    pkgs.grim
    pkgs.brightnessctl
    pkgs.ddcutil
    pkgs.hyprpicker
    pkgs.imagemagick
    pkgs.rclone
    pkgs.python3
    pkgs.bash
    pkgs.libnotify
    pkgs.xdg-utils
    pkgs.util-linux
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnused
    pkgs.gnugrep
    pkgs.which
  ];

  # [Clavis CLI & Native Sysmon]
  key-cli = pkgs.python3Packages.buildPythonApplication rec {
    pname = "key-cli";
    version = "2026.9.25";
    pyproject = true;
    src = pkgs.fetchurl {
      url = "https://github.com/StatIndet/key-cli/releases/download/v${version}/key-cli-${version}.tar.gz";
      hash = "sha256-KVbNKLbOfI3LtkZhtx3xWfovjnl8EUdh+dauxuYyenU=";
    };
    build-system = [
      pkgs.python3Packages.setuptools
    ];
    dependencies = [
      pkgs.python3Packages.evdev
      pkgs.python3Packages.pyudev
    ];
    nativeBuildInputs = [
      pkgs.cmake
      pkgs.ninja
      pkgs.qt6.wrapQtAppsHook
    ];
    buildInputs = [
      pkgs.qt6.qtbase
    ];
    dontUseCmakeConfigure = true;
    dontWrapQtApps = true;
    postBuild = ''
      cmake -S native -B native/build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$out \
        -DCMAKE_INSTALL_LIBEXECDIR=lib \
        -DBUILD_TESTING=OFF
      cmake --build native/build
    '';
    postInstall = ''
      cmake --install native/build
    '';
    makeWrapperArgs = [
      "--prefix" "PATH" ":" (lib.makeBinPath clavisRuntimeBins)
      "--prefix" "NIXPKGS_QT6_QML_IMPORT_PATH" ":" (mkQmlImportPath clavisQtPackages)
      "--prefix" "QML2_IMPORT_PATH" ":" (mkQmlImportPath clavisQtPackages)
      "--prefix" "QT_PLUGIN_PATH" ":" (mkQtPluginPath clavisQtPackages)
      "--prefix" "XDG_CONFIG_DIRS" ":" "${clavis-shell}/etc/xdg"
      "--set" "KEY_CLI_SYSMON" "${placeholder "out"}/bin/key-sysmon"
    ];
    doCheck = false;
  };
in
{
  # [Fonts & Packages]
  fonts.fontconfig.enable = true;

  home.packages = [
    key-cli
    clavis-shell
    qt6-m3shapes
    pkgs.material-symbols
    pkgs.lxgw-wenkai-screen
    pkgs.libqalculate
  ];

  # [XDG Config]
  xdg.configFile."quickshell/clavis".source = "${clavis-shell}/etc/xdg/quickshell/clavis";

  # [Services]
  systemd.user.services.clavis-clipboard = {
    Unit = {
      Description = "Clavis clipboard watcher";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${key-cli}/bin/key clipboard watch";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  systemd.user.services.clavis-shell = {
    Unit = {
      Description = "Clavis Shell (StatIndet/quickshell)";
      After = [ "graphical-session.target" "clavis-clipboard.service" ];
      Wants = [ "clavis-clipboard.service" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      Environment = [ "MALLOC_CONF=thp:never,narenas:4,dirty_decay_ms:3000" ];
      ExecStart = "${key-cli}/bin/key shell --foreground --no-duplicate";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 10;
    };
  };
}
