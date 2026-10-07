# ---
# Module: Hopper Jupyter PDF Export
# Description: Nbconvert configuration, CJK fonts, and XeLaTeX templates for PDF export
# Scope: Host
# ---

{ lib, pkgs, ... }:

let
  jupyterNbconvertConfig = ''
    c.TemplateExporter.extra_template_basedirs = ["/etc/jupyter/nbconvert/templates"]
    c.PDFExporter.template_name = "ctex"
    c.PDFExporter.latex_command = ["xelatex", "{filename}", "-quiet"]
  '';
in {
  environment.etc."jupyter/jupyter_nbconvert_config.py".text = jupyterNbconvertConfig;
  environment.etc."jupyter/jupyter_server_config.py".text = jupyterNbconvertConfig;

  environment.etc."jupyter/nbconvert/templates/ctex/conf.json".text = builtins.toJSON {
    base_template = "latex";
  };

  environment.etc."jupyter/nbconvert/templates/ctex/index.tex.j2".text =
    lib.replaceStrings
      [ "@JETBRAINS_MONO@" "@SOURCE_HAN_SANS@" "@LXGW_WENKAI@" ]
      [
        "${pkgs.jetbrains-mono}/share/fonts/truetype/"
        "${pkgs.source-han-sans}/share/fonts/truetype/"
        "${pkgs.lxgw-wenkai}/share/fonts/truetype/"
      ]
      (builtins.readFile ./templates/index.tex.j2);

  fonts.packages = [
    pkgs.noto-fonts-cjk-sans
    pkgs.noto-fonts-cjk-serif
    pkgs.source-han-sans
    pkgs.jetbrains-mono
    pkgs.lxgw-wenkai
  ];
}
