# ---
# Module: System i18n Environment
# Description: System-wide locale environment variables for shells and sessions
# Scope: System
# ---

{ ... }: {
  environment.variables = {
    LANG = "zh_CN.UTF-8";
    LANGUAGE = "zh_CN:zh";
  };
  environment.sessionVariables = {
    LANG = "zh_CN.UTF-8";
    LANGUAGE = "zh_CN:zh";
  };
}
