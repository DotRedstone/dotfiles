# ---
# Module: Development Entry
# Description: Aggregated development environments for Warden
# Scope: Home Manager
# ---

{
  imports = [
    ./cpp.nix
    ./java.nix
    ./node.nix
    ./python.nix
    ./scripts-runtime.nix
  ];
}
