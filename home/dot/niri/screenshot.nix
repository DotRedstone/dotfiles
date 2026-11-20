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

    # slurp 支持跨输出选区，而 niri 原生 screenshot 的交互选区只覆盖单输出。
    # grim 与 tesseract 都能直接走 stdin/stdout，不需要落临时文件。
    geometry="$(${pkgs.slurp}/bin/slurp)" || exit 0
    ${pkgs.grim}/bin/grim -g "$geometry" - \
      | ${tesseract}/bin/tesseract stdin stdout -l chi_sim+eng --psm 3 2>/dev/null \
      | ${pkgs.wl-clipboard}/bin/wl-copy --type 'text/plain;charset=utf-8'
  '';
in
{
  home.packages = [ niri-ocr ];
}
