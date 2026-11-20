# ---
# Module: UU Remote Linux Package
# Description: 从固定版本源码构建非官方 UU 远程 Linux 被控端（原生 Wayland 后端）
# Scope: Home Manager
# ---
# Notes:
# - 只启用 `wayland` 特性：niri 走 wlroots 原生协议，不需要 portal / libei。
# - 引擎以 dlopen 加载 libpam、托盘与 VAAPI 库；这些库通过 wrapper 的 LD_LIBRARY_PATH 提供。
# - niri、systemctl、loginctl 取自会话 PATH，不在此固定版本，避免与运行中的合成器不一致。

{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  wayland-scanner,
  makeWrapper,
  wayland,
  libxkbcommon,
  libx11,
  libxext,
  libxtst,
  libxfixes,
  gtk3,
  ffmpeg-full,
  wl-clipboard,
  pulseaudio,
  coreutils,
  pam,
  libayatana-appindicator,
  libva,
  libgbm,
  libopus,
}:

rustPlatform.buildRustPackage rec {
  pname = "uu-remote-linux";
  version = "0.2.59";

  src = fetchFromGitHub {
    owner = "VallierDev";
    repo = "uu-remote-linux";
    rev = "v${version}";
    hash = "sha256-kZrcZJMe7MGib6O187QtDrdrn0hoa1RnYai5p84B5z4=";
  };

  cargoHash = "sha256-9o3tYixnI62YIRa6MBVoNzPBhn3MidUybDp70i7YnJQ=";

  buildFeatures = [ "wayland" ];
  cargoBuildFlags = [ "--bin" "uuremote-server" ];

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
    makeWrapper
  ];

  buildInputs = [
    wayland
    libxkbcommon
    libx11
    libxext
    libxtst
    libxfixes
    gtk3
  ];

  # 上游测试依赖图形会话与网络，沙箱内不可用。
  doCheck = false;

  postInstall = ''
    install -Dm644 contrib/desktop/uu-remote-linux.svg \
      $out/share/icons/hicolor/scalable/apps/uu-remote-linux.svg
    install -Dm644 contrib/desktop/uu-remote-linux.desktop \
      $out/share/applications/uu-remote-linux.desktop
    substituteInPlace $out/share/applications/uu-remote-linux.desktop \
      --replace-fail "Exec=uuremote-server" "Exec=$out/bin/uuremote-server"

    wrapProgram $out/bin/uuremote-server \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg-full wl-clipboard pulseaudio coreutils ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pam libayatana-appindicator libva libgbm pulseaudio libopus ]}
  '';

  meta = {
    description = "Unofficial Linux host for NetEase UU Remote";
    homepage = "https://github.com/VallierDev/uu-remote-linux";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "uuremote-server";
  };
}
