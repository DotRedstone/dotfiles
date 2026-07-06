# ---
# Module: System Development
# Description: System-level development tools and hardware rules
# Scope: System
# ---

{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.android-tools ];
}
