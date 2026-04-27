# ---
# Module: Noctalia Program
# Description: Noctalia-shell configuration and package overrides
# ---

{ pkgs, inputs, ... }: {
  programs.noctalia-shell = {
    enable = true;
    # [Package Wrapper]
    # We wrap the original package to inject the API key from sops-nix
    package = let
      basePackage = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        calendarSupport = true;
      };
    in pkgs.symlinkJoin {
      name = "noctalia-shell-wrapped";
      paths = [ basePackage ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/noctalia-shell \
          --run 'if [ -f "$HOME/.config/sops-nix/secrets/gemini_api_key" ]; then export NOCTALIA_AP_GOOGLE_API_KEY=$(cat "$HOME/.config/sops-nix/secrets/gemini_api_key"); fi'
      '';
    };
  };
}
