# ---
# Module: Hopper Backup Services
# Description: Restic local backup task and remote node backup receiver
# Scope: Host
# ---

{ ... }: {
  dot.services = {
    resticBackup.enable = true;
    resticReceiver = {
      enable = true;
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFAKBkZaDY7O0b+Z3PuW4TVXg8NOpADF6YGkC2EqY7WA restic-conduit-to-hopper"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWQ6LPq45Hr6ZMdlGZq0X929eVk9YnZ07yfNFtj06/F restic-target-to-hopper"
      ];
    };
  };
}
