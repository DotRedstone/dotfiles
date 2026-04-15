# ---
# Module: i18n
# Description: System locale and Fcitx5 input method configuration
# ---

{ pkgs, ... }: {
  # [Locale]
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  environment.etc."machine-id".text = "2ff1b656a580496793ee96248624a908";

  # [Input Method]
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        (fcitx5-rime.override { rimeDataPkgs = [ pkgs.rime-data pkgs.rime-ice ]; })
      ];
    };
  };
}
