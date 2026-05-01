# ---
# Module: QQ
# Description: Installs Tencent QQ with libsecret password-store support
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = [
    (pkgs.qq.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    })
  ];
}
