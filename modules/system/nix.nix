# ---
# Module: Nix Compatibility Shim
# Description: Imports the atomized Nix system module tree
# Scope: System
# ---

{ ... }: {
  imports = [ ./nix ];
}
