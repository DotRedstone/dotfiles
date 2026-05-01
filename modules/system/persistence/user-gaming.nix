# ---
# Module: Persistence - User Gaming
# Description: Steam, PrismLauncher, and other gaming platform data
# Scope: System
# ---

{ ... }: {
  environment.persistence."/persist".users.dot = {
    directories = [
      ".local/share/Steam"
      ".steam"
      ".local/share/PrismLauncher"
    ];
  };
}
