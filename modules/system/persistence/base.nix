# ---
# Module: Persistence - Base
# Description: Impermanence module activation and FUSE configuration
# Scope: System
# ---

{ inputs, ... }: {
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  programs.fuse.userAllowOther = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [];
    files = [];
  };
}
