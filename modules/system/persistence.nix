# ---
# Module: Persistence Compatibility Shim
# Description: Imports the atomized persistence module tree
# Scope: System
# Notes:
# - Do not persist /etc/shadow, /etc/passwd, /etc/group, or /etc/gshadow
# ---

{ ... }: {
  imports = [ ./persistence ];
}
