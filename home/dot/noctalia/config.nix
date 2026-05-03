# ---
# Module: Noctalia Program
# Description: Noctalia-shell configuration and package overrides
# Scope: Home Manager
# ---

{ pkgs, inputs, ... }: {
  programs.noctalia-shell = {
    enable = true;

    # [Package Wrapper]
    #
    # Goal:
    #   Keep Noctalia's plugin files and settings.json free of API keys.
    #   The assistant-panel plugin already reads NOCTALIA_AP_GOOGLE_API_KEY,
    #   so the wrapper only bridges the decrypted sops-nix secret into the
    #   process environment at launch time.
    #
    # Path contract:
    #   sops-nix Home Manager defaults place secret symlinks under
    #   ~/.config/sops-nix/secrets. `gemini_api_key` therefore resolves to:
    #   ~/.config/sops-nix/secrets/gemini_api_key
    #
    # Failure mode:
    #   If the secret has not been materialized yet, Noctalia still starts; it
    #   simply runs without the injected Google API key until the next restart.
    #   Re-apply home-manager/sops-nix and restart Noctalia to fix.
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
          --run 'gemini_path="$HOME/.config/sops-nix/secrets/gemini_api_key"; if [ -r "$gemini_path" ]; then export NOCTALIA_AP_GOOGLE_API_KEY="$(cat "$gemini_path")"; fi' \
          --run 'wallhaven_path="$HOME/.config/sops-nix/secrets/wallhaven_api_key"; if [ -r "$wallhaven_path" ]; then export NOCTALIA_WALLHAVEN_API_KEY="$(cat "$wallhaven_path")"; fi'
      '';
    };
  };
}
