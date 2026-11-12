# ---
# Module: Firefox - Extensions
# Description: Enterprise policy-based declarative extensions
# Scope: Home Manager
# ---

{ ... }: {
  programs.firefox.policies = {
    PasswordManagerEnabled = false;
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
    OfferToSaveLogins = false;

    ExtensionSettings = {
      # Pywalfox
      "pywalfox@frewacom.org" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/pywalfox/latest.xpi";
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
      "immersive-translate@owenyoung.com" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/immersive-translate/latest.xpi";
        installation_mode = "force_installed";
      };
    };
  };
}
