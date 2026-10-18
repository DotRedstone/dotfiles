# ---
# Module: Niri Screenshot OCR
# Description: 识别所选屏幕区域的中英文文字并复制到剪贴板
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  tesseract = pkgs.tesseract.override {
    enableLanguages = [ "eng" "chi_sim" ];
  };
  niri-ocr = pkgs.writeShellScriptBin "niri-ocr" ''
    set -euo pipefail

    geometry="$(${pkgs.slurp}/bin/slurp)" || exit 0
    image="$(${pkgs.coreutils}/bin/mktemp "''${XDG_RUNTIME_DIR:-/tmp}/niri-ocr-XXXXXX.png")"
    trap '${pkgs.coreutils}/bin/rm -f "$image"' EXIT

    ${pkgs.grim}/bin/grim -g "$geometry" "$image"
    ${tesseract}/bin/tesseract "$image" stdout -l chi_sim+eng --psm 3 2>/dev/null \
      | ${pkgs.wl-clipboard}/bin/wl-copy --type 'text/plain;charset=utf-8'
  '';
in
{
  home.packages = [ niri-ocr ];
}
