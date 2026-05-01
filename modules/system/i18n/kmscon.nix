# ---
# Module: System KMSCON
# Description: Hardware-accelerated Linux console replacement with multi-font support
# Scope: System
# ---

{ pkgs, ... }: {
  services.kmscon = {
    enable = true;
    hwRender = true;
    fonts = [
      {
        name = "Maple Mono NF";
        package = pkgs.maple-mono.NF;
      }
    ];
    extraConfig = "font-size=12";
  };
}
