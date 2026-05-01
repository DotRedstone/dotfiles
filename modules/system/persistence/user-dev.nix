# ---
# Module: Persistence - User Dev
# Description: Development environments, projects, and editor state
# Scope: System
# ---

{ ... }: {
  environment.persistence."/persist".users.dot = {
    directories = [
      "Code"
      "Projects"
      ".local/share/nvim"
      ".local/state/nvim"
      ".config/Code"
      ".vscode"
      ".config/Antigravity"
      ".antigravity"
    ];
  };
}
