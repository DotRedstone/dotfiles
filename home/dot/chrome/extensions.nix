# ---
# Module: Chrome - Extensions
# Description: Declarative extension management for Chrome
# Scope: Home Manager
# ---

{ ... }: {
  programs.google-chrome.extensions = [
    "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
    "bpoadfkcbjbfhfodiijcnhpobbhcgcob" # Immersive Translate
  ];
}
