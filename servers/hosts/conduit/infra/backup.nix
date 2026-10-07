# ---
# Module: Conduit Backup Client
# Description: Restic isolated client shipping mesh directory to Hopper backup receiver
# Scope: Host
# ---

{ ... }: {
  dot.services.resticClient = {
    enable = true;
    receiverHost = "140.245.62.36";
    receiverHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmQulEZ0fvRUFaP4tH4XaQu047CwW9KUjd8sqGcmc1p";
    repositoryName = "conduit";
    paths = [ "/var/lib/easytier" ];
  };
}
