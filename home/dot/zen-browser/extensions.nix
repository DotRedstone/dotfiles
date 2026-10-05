# ---
# Module: Zen Browser - Extensions
# Description: Enterprise policy-based declarative extensions and Simplified Chinese language pack
# Scope: Home Manager
# ---

{ ... }: {
  programs.zen-browser.policies = {
    ExtensionSettings = {
      # Simplified Chinese Language Pack (Gecko 156)
      "langpack-zh-CN@firefox.mozilla.org" = {
        install_url = "https://releases.mozilla.org/pub/firefox/releases/156.0.1/linux-x86_64/xpi/zh-CN.xpi";
        installation_mode = "force_installed";
      };
      # Pywalfox
      "pywalfox@frewacom.org" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/pywalfox/latest.xpi";
        installation_mode = "force_installed";
      };
      # Bitwarden
      "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
        installation_mode = "force_installed";
      };
      # Dark Reader
      "addon@darkreader.org" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
        installation_mode = "force_installed";
      };
      # Immersive Translate
      "{5efceaa7-f3a2-4e59-a54b-85319448e305}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/immersive-translate/latest.xpi";
        installation_mode = "force_installed";
      };
      # Violentmonkey (暴力猴)
      "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/violentmonkey/latest.xpi";
        installation_mode = "force_installed";
      };
      # Tampermonkey (油猴)
      "firefox@tampermonkey.net" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/tampermonkey/latest.xpi";
        installation_mode = "force_installed";
      };
    };
  };
}
