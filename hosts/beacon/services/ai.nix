# ---
# Module: Beacon AI Service
# Description: Apple Silicon Metal accelerated Ollama inference daemon and DSH runtime
# Scope: Host
# ---

{ pkgs, lib, config, ... }:

let
  cfg = config.services.beacon-ai;
  aiDir = "/Users/dot/.dsh";

  # [DSH Launcher Helper]
  # Provides an entry script for DeepSeek Harness / Agent CLI workflows.
  dshLauncher = pkgs.writeShellScriptBin "dsh-run" ''
    set -euo pipefail
    mkdir -p "${aiDir}"
    cd "${aiDir}"

    export OPENAI_BASE_URL="http://127.0.0.1:11434/v1"
    export OPENAI_API_KEY="ollama"

    echo "[DSH] Initializing DeepSeek Harness runtime environment..."
    echo "[DSH] Inference Backend: $OPENAI_BASE_URL"
    if [ "$#" -gt 0 ]; then
      exec "$@"
    else
      echo "[DSH] Ready. Run with your agent task or inspect ~/.dsh/config.yaml."
    fi
  '';
in
{
  options.services.beacon-ai = {
    enable = lib.mkEnableOption "AI services including Ollama (Metal) and DSH Agent runtime";
    ollamaPort = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port for the local Ollama inference server.";
    };
  };

  config = lib.mkIf cfg.enable {
    # [Packages]
    environment.systemPackages = [
      pkgs.ollama
      dshLauncher
      pkgs.curl
      pkgs.jq
    ];

    # [Launchd Service - Ollama Daemon]
    # Native Metal acceleration on Apple Silicon unified memory.
    launchd.user.agents.ollama = {
      serviceConfig = {
        Label = "org.nix-darwin.ollama";
        ProgramArguments = [
          "${pkgs.ollama}/bin/ollama"
          "serve"
        ];
        EnvironmentVariables = {
          OLLAMA_HOST = "0.0.0.0:${toString cfg.ollamaPort}";
          OLLAMA_MODELS = "/Users/dot/.ollama/models";
          OLLAMA_ORIGINS = "*";
        };
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/Users/dot/.ollama/launchd-stdout.log";
        StandardErrorPath = "/Users/dot/.ollama/launchd-stderr.log";
      };
    };
  };
}
