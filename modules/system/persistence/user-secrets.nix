# ---
# Module: Persistence - User Secrets
# Description: Keyrings, sops age keys, and other sensitive session state
# Scope: System
# ---

{ ... }: {
  environment.persistence."/persist".users.dot = {
    directories = [
      ".config/sops"
      ".local/share/keyrings"
    ];
  };
}
