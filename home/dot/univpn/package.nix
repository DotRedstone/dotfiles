# ---
# Module: UniVPN Package
# Description: Official UniVPN client wrapped in an FHS environment
# Scope: Home Manager
# ---

{ pkgs }:
let
  pname = "univpn";
  version = "10781.9.0.1229";

  src = pkgs.fetchurl {
    url = "https://download.leagsoft.com/download/UniVPN/linux/univpn-linux-64-${version}.zip";
    hash = "sha256-jBXBJbnIqeYh2Wq9xJgZTOwXHP+I/2HD/oY53i8J3SU=";
  };

  unpacked = pkgs.runCommand "${pname}-unpacked-${version}" {
    nativeBuildInputs = [ pkgs.unzip pkgs.gnutar pkgs.gzip ];
  } ''
    unzip -q ${src}
    mkdir -p $out
    tail -n +227 */*.run | tar -zx -C $out
    chmod +x $out/UniVPN $out/serviceclient/UniVPNCS $out/promote/UniVPNPromoteService
  '';

  fhs = pkgs.buildFHSEnv {
    name = "${pname}-fhs";

    targetPkgs = pkgs: with pkgs; [
      stdenv.cc.cc.lib
      glibc
      zlib
      openssl
      glib
      fontconfig
      freetype
      dbus

      # X11 & XCB
      libx11
      libxext
      libxrender
      libxrandr
      libxcursor
      libxfixes
      libxi
      libxtst
      libxcb
      libxcb-wm
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-util
      libxkbcommon
      libGL

      # Network utils
      iproute2
      iptables
      procps
      nettools
      coreutils
      bash
      which
    ];

    extraBuildCommands = ''
      mkdir -p $out/usr/local/UniVPN
    '';

    extraBwrapArgs = [
      "--bind" "/var/lib/univpn" "/usr/local/UniVPN"
    ];

    runScript = pkgs.writeShellScript "univpn-fhs-runner" ''
      unset QT_PLUGIN_PATH
      unset QT_QPA_PLATFORMTHEME
      unset QML2_IMPORT_PATH
      export QT_QPA_PLATFORM=xcb
      export LD_LIBRARY_PATH="/usr/local/UniVPN/lib:$LD_LIBRARY_PATH"
      cd /usr/local/UniVPN
      exec /usr/local/UniVPN/UniVPN "$@"
    '';
  };

  launcher = pkgs.writeShellScriptBin "univpn" ''
    if [ "$(id -u)" -eq 0 ]; then
      WORK_DIR="/var/lib/univpn"
      PERSIST_DIR="/persist/var/lib/univpn"

      # 兜底持久化保障：在 root 权限下确保物理持久化目录存在且实时挂载
      if [ -d "/persist" ]; then
        mkdir -p "$PERSIST_DIR"
        if ! mountpoint -q "$WORK_DIR"; then
          mkdir -p "$WORK_DIR"
          if [ -f "$WORK_DIR/sysconfig.ini" ] && [ ! -f "$PERSIST_DIR/sysconfig.ini" ]; then
            cp -a "$WORK_DIR"/* "$PERSIST_DIR/" 2>/dev/null || true
          fi
          mount --bind "$PERSIST_DIR" "$WORK_DIR" 2>/dev/null || true
        fi
      fi

      mkdir -p "$WORK_DIR"
      if [ ! -f "$WORK_DIR/sysconfig.ini" ]; then
        cp -a --no-preserve=mode,ownership ${unpacked}/* "$WORK_DIR/"
      else
        cp -a --no-preserve=mode,ownership --update \
          ${unpacked}/UniVPN ${unpacked}/serviceclient ${unpacked}/promote ${unpacked}/lib ${unpacked}/plugins \
          "$WORK_DIR/" 2>/dev/null || true
      fi
      chmod -R a+rwX "$WORK_DIR"
      chmod a+rx "$WORK_DIR/UniVPN" "$WORK_DIR/UniVPNUpdate" "$WORK_DIR/promote/UniVPNPromoteService" "$WORK_DIR/serviceclient/UniVPNCS"

      exec ${fhs}/bin/${pname}-fhs "$@"
    fi

    # 启动 XEmbed -> SNI 托盘代理，确保 UniVPN 的传统 X11 托盘图标能在 Wayland 状态栏正常显示
    if ! pgrep -x xembedsniproxy >/dev/null 2>&1; then
      ${pkgs.kdePackages.plasma-workspace}/bin/xembedsniproxy >/dev/null 2>&1 &
    fi

    # 优先使用 pkexec 以 root 权限运行，确保拥有创建 TUN 网卡与配置路由的权限
    if command -v pkexec >/dev/null 2>&1; then
      # 授权 root 用户连接当前 X11 / XWayland 屏幕
      ${pkgs.xhost}/bin/xhost +si:localuser:root >/dev/null 2>&1 || true

      exec pkexec env \
        DISPLAY="''${DISPLAY:-:0}" \
        XAUTHORITY="$XAUTHORITY" \
        "$0" "$@"
    else
      echo "Error: UniVPN requires root privileges to configure network tunnel." >&2
      exit 1
    fi
  '';
in
pkgs.symlinkJoin {
  name = "${pname}-${version}";
  paths = [
    launcher
    fhs
  ];

  postBuild = ''
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${unpacked}/image/logo.png $out/share/icons/hicolor/256x256/apps/univpn.png 2>/dev/null || true

    mkdir -p $out/share/applications
    cat > $out/share/applications/univpn.desktop << 'EOF'
[Desktop Entry]
Name=UniVPN
Comment=UniVPN Client (Huawei / Leagsoft)
Exec=univpn
Icon=univpn
Terminal=false
Type=Application
Categories=Network;VPN;
StartupWMClass=UniVPN
EOF
  '';
}
