# ---
# Module: Network - EasyTier
# Description: Mesh VPN networking service using EasyTier Core
# Scope: System
# ---

{ pkgs, ... }:

let
  easytier-start = pkgs.writeShellScriptBin "easytier-start" ''
    set -e
    # Load environment variables if file exists
    if [ -f /persist/secrets/easytier.env ]; then
      set -a
      source /persist/secrets/easytier.env
      set +a
    fi

    # Validation
    MISSING=""
    if [ -z "$EASYTIER_NETWORK_NAME" ]; then MISSING="$MISSING EASYTIER_NETWORK_NAME"; fi
    if [ -z "$EASYTIER_NETWORK_SECRET" ]; then MISSING="$MISSING EASYTIER_NETWORK_SECRET"; fi

    if [ -n "$MISSING" ]; then
      echo "Error: Missing required environment variables:$MISSING" >&2
      echo "Please configure them in /persist/secrets/easytier.env" >&2
      exit 1
    fi

    # Build arguments
    ARGS=(
      "--network-name" "$EASYTIER_NETWORK_NAME"
      "--network-secret" "$EASYTIER_NETWORK_SECRET"
    )

    if [ -n "$EASYTIER_IPV4" ]; then
      ARGS+=("--ipv4" "$EASYTIER_IPV4")
    fi

    if [ -n "$EASYTIER_PEERS" ]; then
      for peer in $EASYTIER_PEERS; do
        ARGS+=("--peers" "$peer")
      done
    fi

    # Extra arguments from env
    if [ -n "$EASYTIER_EXTRA_ARGS" ]; then
      # Use read -ra to split by whitespace safely
      read -ra EXTRA <<< "$EASYTIER_EXTRA_ARGS"
      ARGS+=("${EXTRA[@]}")
    fi

    echo "Starting EasyTier Core for network: $EASYTIER_NETWORK_NAME"
    # Execute directly so it takes over the PID and receives signals
    exec ${pkgs.easytier}/bin/easytier-core "${ARGS[@]}"
  '';

  easytier-status = pkgs.writeShellScriptBin "easytier-status" ''
    if ! systemctl is-active --quiet easytier; then
      echo '{"status": "inactive", "peer_count": 0}'
      exit 0
    fi

    # Get peer count from easytier-cli
    # We grep for lines starting with | and then count them, subtracting 3 for headers/separators
    PEER_COUNT=$(${pkgs.easytier}/bin/easytier-cli peer 2>/dev/null | grep -c "^|" || echo 0)
    
    # If PEER_COUNT > 3, subtract 3 (header lines)
    if [ "$PEER_COUNT" -gt 3 ]; then
      PEER_COUNT=$((PEER_COUNT - 3))
    else
      PEER_COUNT=0
    fi
    
    echo "{\"status\": \"active\", \"peer_count\": $PEER_COUNT}"
  '';

  easytier-restart = pkgs.writeShellScriptBin "easytier-restart" ''
    echo "Restarting EasyTier service..."
    sudo systemctl restart easytier
  '';
in
{
  environment.systemPackages = [
    pkgs.easytier
    easytier-start
    easytier-status
    easytier-restart
  ];

  systemd.services.easytier = {
    description = "EasyTier Mesh VPN Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${easytier-start}/bin/easytier-start";
      Restart = "on-failure";
      RestartSec = "5s";
      
      # Security and Environment
      EnvironmentFile = "-/persist/secrets/easytier.env";
      
      # Harden service
      CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_RAW";
      AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_RAW";
    };
  };
}
