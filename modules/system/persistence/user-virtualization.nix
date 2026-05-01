# ---
# Module: Persistence - User Virtualization
# Description: Virtual machine configurations and state for user 'dot'
# Scope: System
# ---

{ ... }: {
  environment.persistence."/persist".users.dot = {
    directories = [
      ".config/virt-manager"
      ".local/share/libvirt"
    ];
  };
}
