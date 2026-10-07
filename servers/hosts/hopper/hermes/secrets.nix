# ---
# Module: Hopper Hermes Secrets
# Description: Sops secrets and environment template configuration for Hermes agent
# Scope: Host
# ---

{ config, ... }: {
  sops.secrets."hermes/siliconflow_api_key" = {
    restartUnits = [ "hermes-agent.service" ];
  };

  sops.secrets."hermes/telegram_bot_token" = {
    restartUnits = [ "hermes-agent.service" ];
  };

  sops.secrets."hermes/telegram_allowed_users" = {
    restartUnits = [ "hermes-agent.service" ];
  };

  sops.templates."hermes.env" = {
    owner = "hermes";
    group = "hermes";
    mode = "0440";
    content = ''
      SILICONFLOW_API_KEY=${config.sops.placeholder."hermes/siliconflow_api_key"}
      TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes/telegram_bot_token"}
      TELEGRAM_ALLOWED_USERS=${config.sops.placeholder."hermes/telegram_allowed_users"}
    '';
  };
}
