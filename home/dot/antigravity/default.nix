# ---
# Module: Google Antigravity AI Agent
# Description: AI-powered coding assistant from Google, integrated via flake package
# Scope: Home Manager
# ---

{ inputs, lib, pkgs, ... }:

let
  antigravity = inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-no-fhs;
  chineseLocalizationVersion = "2.17.0-5217732355031040";
  chineseLocalization = pkgs.fetchFromGitHub {
    owner = "Silas-02";
    repo = "antigravity2-win-linux-cn";
    rev = "f3cdcf59a187b88de8cb755f15a68f41868d9469";
    hash = "sha256-Mk3M5BGJ2O6ax2zYqp/l+K7N+P/itM5trCORVuPcTRQ=";
  };
  localizedAntigravity = assert lib.assertMsg
    (antigravity.version == chineseLocalizationVersion)
    "Antigravity version changed; update the Chinese localization source before rebuilding.";
  antigravity.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.nodejs ];
    postInstall = (old.postInstall or "") + ''
      # The upstream localization project targets this pinned 2.17.0 client.
      # Patch a build-local copy so the immutable Nix store stays reproducible.
      localization_resources="$out/lib/google-antigravity2/resources"
      localization_tmp="$(mktemp -d)"
      trap 'rm -rf "$localization_tmp"' EXIT

      mkdir -p "$localization_tmp/bin"
      cat > "$localization_tmp/bin/npx" <<'EOF'
      #!${pkgs.runtimeShell}
      set -eu
      if [ "$1" = "-y" ] && [ "$2" = "@electron/asar" ]; then
        shift 2
        exec ${pkgs.asar}/bin/asar "$@"
      fi
      echo "Unexpected npx invocation while localizing Antigravity" >&2
      exit 64
      EOF
      chmod +x "$localization_tmp/bin/npx"

      cp -R ${chineseLocalization} "$localization_tmp/source"
      chmod -R u+w "$localization_tmp/source"
      PATH="$localization_tmp/bin:$PATH" node "$localization_tmp/source/localization_engine.js" \
        --no-kill \
        --brand-title english \
        --install-dir "$localization_resources"

      rm -f "$localization_resources/app.asar.bak"
      ${pkgs.asar}/bin/asar extract "$localization_resources/app.asar" "$localization_tmp/verify"
      grep -Fq "__ANTIGRAVITY_CHINESE_LOCALIZATION_START__" \
        "$localization_tmp/verify/dist/preload.js"
    '';
  });
in
{
  home.packages = [
    (pkgs.symlinkJoin {
      name = "google-antigravity-with-keyring";
      paths = [ localizedAntigravity ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        rm -f $out/bin/antigravity
        makeWrapper ${localizedAntigravity}/bin/antigravity $out/bin/antigravity \
          --add-flags "--password-store=gnome-libsecret"
      '';
    })
  ];

  xdg.desktopEntries.antigravity = {
    name = "Google Antigravity";
    genericName = "智能开发环境";
    comment = "新一代智能 AI 编程开发环境";
    exec = "antigravity %U";
    icon = "antigravity";
    terminal = false;
    categories = [ "Development" "IDE" ];
    mimeType = [ "x-scheme-handler/antigravity" ];
    settings = {
      StartupWMClass = "Antigravity";
    };
  };
}
