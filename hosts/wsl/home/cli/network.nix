# ---
# Module: Network & Data CLI
# Description: Network diagnostics and structured data processors
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    jq
    yq-go
    dig
    socat
    iperf3
    aria2
  ];
}
