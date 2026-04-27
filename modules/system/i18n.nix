# ---
# Module: i18n
# Description: System locale and Fcitx5 input method configuration
# ---

{ pkgs, ... }: {
  # [Locale]
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  # [Locales Archive]
  i18n.supportedLocales = [ "zh_CN.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];

  # [Environment]
  environment.variables = {
    LANG = "zh_CN.UTF-8";
    LANGUAGE = "zh_CN:zh";
  };
  environment.sessionVariables = {
    LANG = "zh_CN.UTF-8";
    LANGUAGE = "zh_CN:zh";
  };

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

  # [KMSCON - Modern TTY]
  # Replaces the Linux console with a hardware-accelerated terminal
  services.kmscon = {
    enable = true;
    hwRender = true;
    fonts = [{
      name = "Maple Mono NF";
      package = pkgs.maple-mono.NF;
    }];
    extraConfig = "font-size=12";
  };
}
