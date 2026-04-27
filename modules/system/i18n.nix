# ---
# Module: i18n
# Description: System locale and Fcitx5 input method configuration
# ---

{ pkgs, lib, ... }: {
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
  # Generating all locales is the most robust way to avoid "missing locale" fallbacks
  i18n.supportedLocales = [ "all" ];
  
  # Ensure glibcLocales is matching the system glibc
  i18n.glibcLocales = pkgs.glibcLocales;

  # Global environment variables
  environment.variables = {
    LANG = "zh_CN.UTF-8";
    LANGUAGE = "zh_CN:zh";
    LC_ALL = "zh_CN.UTF-8";
  };

  # Session variables for Wayland (automatically inherited by systemd --user)
  environment.sessionVariables = {
    LANG = "zh_CN.UTF-8";
    LANGUAGE = "zh_CN:zh";
    LC_ALL = "zh_CN.UTF-8";
  };

  # Force systemd user session to inherit these
  systemd.user.extraConfig = ''
    DefaultEnvironment="LANG=zh_CN.UTF-8" "LANGUAGE=zh_CN:zh" "LC_ALL=zh_CN.UTF-8"
  '';

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
