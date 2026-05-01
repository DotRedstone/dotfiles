# ---
# Module: System Machine-ID
# Description: Fixed machine-id for consistency across boots and persistence
# Scope: System
# ---

{ ... }: {
  environment.etc."machine-id".text = "2ff1b656a580496793ee96248624a908";
}
