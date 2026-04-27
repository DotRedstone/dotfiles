# ---
# Module: QQ
# Description: Tencent QQ client
# ---

{ pkgs, ... }: {
  home.packages = [
    (pkgs.qq.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    })
  ];
}
