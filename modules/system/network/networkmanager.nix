# ---
# Module: Network - NetworkManager
# Description: Enable NetworkManager with normal wired default-route behavior
# Scope: System
# ---

{ ... }:

{
  networking.networkmanager = {
    enable = true;
  };
}
