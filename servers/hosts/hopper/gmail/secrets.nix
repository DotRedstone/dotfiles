# ---
# Module: Hopper Gmail Secrets
# Description: SOPS secret definitions and environment template for gmail-archiver
# Scope: Host
# ---

{ config, ... }: {
  sops.secrets."gmail/imap_password" = {
    restartUnits = [ "gmail-archiver.service" ];
  };

  sops.templates."gmail-archiver.env" = {
    mode = "0400";
    content = ''
      IMAP_PASSWORD=${config.sops.placeholder."gmail/imap_password"}
    '';
  };
}
