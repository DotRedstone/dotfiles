# ---
# Module: Hopper Hermes Agent
# Description: Private document-focused Hermes service using the SiliconFlow-compatible API.
# Scope: Host
# Notes:
# - Hermes has no dashboard or Docker runtime; Telegram is the only messaging surface.
# - Do not add third-party MCP servers or optional skill dependencies without a specific need.
# ---

{
  config,
  hermes-agent,
  lib,
  pkgs,
  ...
}:

{
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

  # `dot` already administers Hopper through passwordless sudo. Membership lets
  # the operator use the shared Hermes CLI and inspect its task output locally.
  users.users.dot.extraGroups = [ "hermes" ];

  # Keep experimental Python dependencies writable but isolated from the
  # Nix-managed service environment.  This stays in Hermes's own workspace,
  # is created once, and survives service restarts and ordinary rebuilds.
  system.activationScripts.hermes-workspace-venv = lib.stringAfter [ "users" ] ''
    venv_dir=/var/lib/hermes/workspace/.venv
    if [ ! -x "$venv_dir/bin/python" ]; then
      ${pkgs.coreutils}/bin/mkdir -p /var/lib/hermes/workspace
      ${pkgs.coreutils}/bin/chown hermes:hermes /var/lib/hermes/workspace
      ${pkgs.util-linux}/bin/runuser -u hermes -- \
        env HOME=/var/lib/hermes \
        ${pkgs.python3}/bin/python3 -m venv --system-site-packages "$venv_dir"
    fi
  '';

  services.hermes-agent = {
    enable = true;
    # The upstream default bundles every optional cloud, voice, memory, and
    # messaging integration. Hopper needs only the core agent and Telegram.
    package = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.messaging;
    addToSystemPackages = true;
    workingDirectory = "/var/lib/hermes/workspace";
    environmentFiles = [ config.sops.templates."hermes.env".path ];
    # Keep the assistant native and reproducible: no mutable OCI container,
    # no third-party MCP server, and no skill extras.
    extraPackages = with pkgs; [
      # Hermes often needs to inspect, generate, or archive office documents.
      # Keep language runtimes available for its own unprivileged workspace;
      # package dependencies belong in Nix or a project virtualenv, never the
      # immutable system Python site-packages.
      python3
      python3Packages.pip
      nodejs
      jdk
      pandoc
      typst
      pkgs."poppler-utils"
      zip
      unzip
      tree
      file
    ];

    settings = {
      model = {
        provider = "custom";
        base_url = "https://api.siliconflow.cn/v1";
        api_key = "\${SILICONFLOW_API_KEY}";
        default = "deepseek-ai/DeepSeek-V3.2";
        # Hermes needs a generous window for tool calls; 64K leaves headroom
        # while avoiding a speculative provider-side maximum.
        context_length = 65536;
        max_tokens = 8192;
      };

      terminal = {
        backend = "local";
        timeout = 120;
        # Do not expose the `hermes` process to the administrator's SSH, Git,
        # or cloud CLI credentials.
        home_mode = "profile";
      };

      agent = {
        max_turns = 16;
        disabled_toolsets = [ "web" ];
      };

      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
        # Durable facts are seeded declaratively below. New learned facts need
        # an explicit review instead of silently becoming operating policy.
        write_approval = true;
      };

      skills.write_approval = true;
      auxiliary.background_review.enabled = false;

      compression = {
        enabled = true;
        threshold = 0.72;
      };

      # Hermes runs with files under /var/lib, which the upstream media policy
      # denies by default. Trust only its own artifact workspace so generated
      # documents can be delivered through Telegram without exposing service
      # state, secrets, or unrelated files beneath /var/lib.
      gateway.media_delivery_allow_dirs = [ "/var/lib/hermes/workspace" ];

      max_concurrent_sessions = 1;
  };

    documents = {
      "AGENTS.md" = ./hermes/AGENTS.md;
    };

    hermesHomeFiles = {
      "SOUL.md" = ./hermes/SOUL.md;
      "memories/MEMORY.md" = ./hermes/MEMORY.md;
      "memories/USER.md" = ./hermes/USER.md;
    };
  };
}
