# ---
# Module: Persistence - User Gaming
# Description: Steam, HMCL, and other gaming platform data
# Scope: System
# ---

{ ... }: {
  environment.persistence."/persist".users.dot = {
    directories = [
      ".local/share/Steam"
      ".steam"
      ".local/share/PrismLauncher"
      ".minecraft"
      ".hmcl"
      ".java"
    ];
  };
}
