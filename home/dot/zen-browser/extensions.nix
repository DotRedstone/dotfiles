# ---
# Module: Zen Browser - Extensions
# Description: Enterprise policy-based declarative extensions and Simplified Chinese language pack
# Scope: Home Manager
# ---

{ ... }: {
  programs.zen-browser.policies = {
    PasswordManagerEnabled = false;
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
    OfferToSaveLogins = false;

    ExtensionSettings = {
      # Simplified Chinese Language Pack (Gecko 156)
      "langpack-zh-CN@firefox.mozilla.org" = {
        install_url = "https://releases.mozilla.org/pub/firefox/releases/156.0.1/linux-x86_64/xpi/zh-CN.xpi";
        installation_mode = "force_installed";
      };
      # 1Password
      "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
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
    };
  };
}
