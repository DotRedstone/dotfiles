# ---
# Module: Hopper JupyterLab Frontend Settings
# Description: Default settings overrides for JupyterLab UI, locale, and themes
# Scope: Host
# ---

{ ... }: {
  environment.etc."jupyter/labconfig/default_setting_overrides.json".text = builtins.toJSON {
    "@jupyterlab/translation-extension:plugin".locale = "zh_CN";

    "@jupyterlab/terminal-extension:plugin" = {
      fontFamily = "'Maple Mono NF', 'Maple Mono', 'JetBrains Mono', 'Fira Code', 'Cascadia Code', 'Sarasa Mono SC', Consolas, monospace";
      fontSize = 14;
      lineHeight = 1.2;
    };

    "@jupyterlab/apputils-extension:themes" = {
      theme = "Catppuccin Mocha";
      "adaptive-theme" = false;
      "theme-scrollbars" = true;
      overrides = {
        "code-font-family" = "'Maple Mono NF', 'Maple Mono', 'JetBrains Mono', 'Fira Code', 'Cascadia Code', 'Sarasa Mono SC', Consolas, monospace";
        "code-font-size" = "14px";
        "content-font-family" = "Inter, Noto Sans SC, system-ui, sans-serif";
        "content-font-size1" = "14px";
        "ui-font-family" = "Inter, Noto Sans SC, system-ui, sans-serif";
        "ui-font-size1" = "13px";
      };
    };

    "catppuccin_jupyterlab:plugin" = {
      brandColor = "mauve";
      accentColor = "green";
    };
  };
}
