# ---
# Module: WorkBuddy Package
# Description: Official WorkBuddy client wrapped in an FHS environment
# Scope: Home Manager
# ---

{ pkgs }:
let
  pname = "workbuddy";
  version = "5.6.2.40046327";

  deb = pkgs.fetchurl {
    url = "https://download.codebuddy.cn/workbuddy/saas/linux-x64-deb/WorkBuddy-linux-x64-deb-${version}-c7b525f3.deb";
    hash = "sha256-EhSa2MDNdI/VBi2PYseCfWiNgJVCetqZsa6ecBmJdSM=";
  };

  unpacked = pkgs.runCommand "workbuddy-unpacked-${version}" {
    nativeBuildInputs = [ pkgs.dpkg ];
  } ''
    dpkg-deb -x ${deb} $out
  '';

  fhs = pkgs.buildFHSEnv (pkgs.appimageTools.defaultFhsEnvArgs // {
    name = pname;
    runScript = pkgs.writeShellScript "workbuddy-runner" ''
      export GTK_THEME="adw-gtk3-dark"
      export ADW_DEBUG_COLOR_SCHEME="prefer-dark"
      exec ${unpacked}/opt/WorkBuddy/workbuddy \
        --ozone-platform-hint=auto \
        --force-dark-mode \
        "$@"
    '';
  });
in
pkgs.symlinkJoin {
  name = "${pname}-${version}";
  paths = [
    fhs
  ];
  postBuild = ''
    mkdir -p $out/share
    cp -r ${unpacked}/usr/share/icons $out/share/
    mkdir -p $out/share/applications
    substitute ${unpacked}/usr/share/applications/workbuddy.desktop $out/share/applications/workbuddy.desktop \
      --replace-fail "/opt/WorkBuddy/workbuddy" "$out/bin/workbuddy"
  '';
}
