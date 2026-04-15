# ---
# Module: SSH Client
# Description: SSH configuration and Minecraft-inspired VPS hostnames
# ---

{ ... }: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # [Match Blocks]
    matchBlocks = {
      "repeater"   = { hostname = "47.110.239.66"; };
      "block"      = { hostname = "154.12.88.182"; };
      "cooperator" = { hostname = "81.69.253.208"; };
      "shulker"    = { hostname = "140.245.62.36"; };
      "dispenser"  = { hostname = "107.174.1.97"; };
    };
  };
}
