# ---
# Module: Hopper JupyterLab Extension Packages
# Description: Custom Python packages and prebuilt JupyterLab frontend extensions
# Scope: Host
# ---

{ pkgs, ... }:

let
  pythonPackages = pkgs.python3Packages;

  chinese = pythonPackages.buildPythonPackage {
    pname = "jupyterlab-language-pack-zh-CN";
    version = "4.5.post3";
    format = "wheel";

    src = pkgs.fetchPypi {
      pname = "jupyterlab_language_pack_zh_cn";
      version = "4.5.post3";
      format = "wheel";
      hash = "sha256-R82wxBxrBm55XIZ3hsnCn95SfivxWqaz6bK6uZKTBLU=";
    };

    doCheck = false;
  };

  catppuccin = pythonPackages.buildPythonPackage {
    pname = "catppuccin-jupyterlab";
    version = "0.2.5";
    format = "wheel";

    src = pkgs.fetchPypi {
      pname = "catppuccin_jupyterlab";
      version = "0.2.5";
      format = "wheel";
      python = "py3";
      dist = "py3";
      hash = "sha256-d5uxZIf3AJ7AX9GEfWdb/+KMTi7xA3Df+SkZgVD6C6Y=";
    };

    doCheck = false;
  };

  themeToggler = pythonPackages.buildPythonPackage {
    pname = "jupyterlab-theme-toggler";
    version = "1.0.0";
    format = "wheel";

    src = pkgs.fetchPypi {
      pname = "jupyterlab_theme_toggler";
      version = "1.0.0";
      format = "wheel";
      python = "py3";
      dist = "py3";
      hash = "sha256-yzcgNQodJL1xD7jyxEKJ8EP52oV3PcQUee7oINRfkoI=";
    };

    postInstall = ''
      substituteInPlace "$out/share/jupyter/labextensions/jupyterlab-theme-toggler/static/789.c7eee2235cc74ef156cd.js" \
        --replace-fail "JupyterLab Light" "Catppuccin Latte" \
        --replace-fail "JupyterLab Dark" "Catppuccin Mocha"
    '';

    propagatedBuildInputs = [ pythonPackages.jupyterlab ];

    doCheck = false;
  };
in {
  _module.args.jupyterExtensions = {
    inherit chinese catppuccin themeToggler;
  };
}
