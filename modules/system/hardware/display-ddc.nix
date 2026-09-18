# ---
# Module: Hardware Display DDC
# Description: Expose I2C DDC access for external display power-state detection
# Scope: System
# ---
# Notes:
# - This only enables the kernel I2C device and local-session access; it does not control monitor settings.

{ ... }:
{
  hardware.i2c.enable = true;
}
