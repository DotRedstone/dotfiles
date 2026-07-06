# ---
# Module: System KMSCON
# Description: Hardware-accelerated Linux console replacement with multi-font support
# Scope: System
# ---

{ ... }:
{
  services.kmscon = {
    enable = true;
    config = {
      hwaccel = true;
      "font-name" = "Maple Mono NF";
      "font-size" = "12";
    };
  };
}
