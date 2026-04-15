# ---
# Module: Noctalia Program
# Description: Noctalia-shell configuration and package overrides
# ---

{ pkgs, inputs, ... }: {
  programs.noctalia-shell = {
    enable = true;
    # [Package Override]
    # Explicitly enable calendar support for the shell environment
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      calendarSupport = true;
    };
  };
}
