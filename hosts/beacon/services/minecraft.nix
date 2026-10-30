# ---
# Module: Beacon Minecraft Service
# Description: Headless Minecraft server daemon with PaperMC and Aikar's GC flags
# Scope: Host
# ---

{ pkgs, lib, config, ... }:

let
  cfg = config.services.minecraft-server;
  dataDir = "/Users/Shared/minecraft";

  # [Startup Script]
  # Ensures directory structure, accepts EULA, and launches with optimized flags.
  startScript = pkgs.writeShellScript "start-minecraft" ''
    set -euo pipefail
    mkdir -p "${dataDir}"
    cd "${dataDir}"

    # Auto-accept EULA for headless deployment
    if [ ! -f eula.txt ]; then
      echo "eula=true" > eula.txt
    fi

    # Check for server JAR; provide initial instructions if absent
    if [ ! -f server.jar ]; then
      echo "[Minecraft] No server.jar found in ${dataDir}."
      echo "[Minecraft] Downloading latest PaperMC build for 1.21.4..."
      ${pkgs.curl}/bin/curl -sLo server.jar "https://api.papermc.io/v2/projects/paper/versions/1.21.4/builds/163/downloads/paper-1.21.4-163.jar" || {
        echo "[Minecraft] Download failed. Place your server.jar in ${dataDir}."
        exit 1
      }
    fi

    # Aikar's Flags for low-latency garbage collection
    exec ${pkgs.temurin-bin-21}/bin/java \
      -Xms4G \
      -Xmx8G \
      -XX:+UseG1GC \
      -XX:+ParallelRefProcEnabled \
      -XX:MaxGCPauseMillis=200 \
      -XX:+UnlockExperimentalVMOptions \
      -XX:+DisableExplicitGC \
      -XX:+AlwaysPreTouch \
      -XX:G1NewSizePercent=30 \
      -XX:G1MaxNewSizePercent=40 \
      -XX:G1ReservePercent=20 \
      -XX:G1HeapWastePercent=5 \
      -XX:G1MixedGCCountTarget=4 \
      -XX:InitiatingHeapOccupancyPercent=15 \
      -XX:G1MixedGCLiveThresholdPercent=90 \
      -XX:G1RSetUpdatingPauseTimePercent=5 \
      -XX:SurvivorRatio=32 \
      -XX:+PerfDisableSharedMem \
      -XX:MaxTenuringThreshold=1 \
      -Dusing.aikars.flags=https://mcflags.emc.gs \
      -Daikars.new.flags=true \
      -jar server.jar nogui
  '';
in
{
  options.services.minecraft-server = {
    enable = lib.mkEnableOption "Headless Minecraft server launchd daemon";
  };

  config = lib.mkIf cfg.enable {
    # [Package]
    environment.systemPackages = [
      pkgs.temurin-bin-21
    ];

    # [Launchd Service]
    # Runs as user 'dot' to maintain proper permissions without requiring root.
    launchd.user.agents.minecraft-server = {
      serviceConfig = {
        Label = "org.nix-darwin.minecraft-server";
        ProgramArguments = [ "${startScript}" ];
        WorkingDirectory = dataDir;
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };
        StandardOutPath = "${dataDir}/logs/launchd-stdout.log";
        StandardErrorPath = "${dataDir}/logs/launchd-stderr.log";
      };
    };
  };
}
