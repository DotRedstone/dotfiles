# ---
# Module: Hopper Gmail Secrets
# Description: SOPS secret definitions and environment template for gmail-archiver
# Scope: Host
# ---

{ config, ... }: {
  sops.secrets."gmail/api_key" = {
    restartUnits = [ "gmail-archiver.service" ];
  };

  sops.secrets."gmail/imap_password" = {
    restartUnits = [ "gmail-archiver.service" ];
  };

  sops.templates."gmail-archiver.env" = {
    mode = "0400";
    content = ''
      API_KEY=${config.sops.placeholder."gmail/api_key"}
      IMAP_PASSWORD=${config.sops.placeholder."gmail/imap_password"}
    '';
  };
}
