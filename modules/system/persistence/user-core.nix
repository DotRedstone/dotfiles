# ---
# Module: Persistence - User Core
# Description: Essential user directories (dotfiles, SSH, documents)
# Scope: System
# ---

{ ... }: {
  environment.persistence."/persist".users.dot = {
    directories = [
      ".dotfiles"
      ".ssh"
      "Documents"
      "Downloads"
      "Pictures"
      ".local/share/fish"
      ".gemini"
    ];
  };
}
