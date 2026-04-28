# ---
# Module: VS Code
# Description: Minimalist VS Code setup; configuration managed via GUI
# ---

{ pkgs, ... }: {
  xdg.configFile."Code/User/argv.json".text = builtins.toJSON {
    "password-store" = "gnome-libsecret";
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    };

    profiles.default = {
      # [Extensions]
      # Managed via Nix for stability; configuration is handled in-app
      extensions = with pkgs.vscode-extensions; [
        # UI & Icons
        catppuccin.catppuccin-vsc-icons


        # Core Productivity
        asvetliakov.vscode-neovim        # Neovim backend integration
        ms-vscode-remote.remote-ssh       # Essential for server management
        eamodio.gitlens                   # Advanced Git insights
        usernamehw.errorlens              # Inline diagnostics
        alefragnani.project-manager       # Workspace switching
        github.copilot-chat               # AI Pair Programming

        # Language Support
        ms-python.python
        llvm-vs-code-extensions.vscode-clangd
        ms-vscode.cpptools
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode
        redhat.java
        vscjava.vscode-java-debug
        vscjava.vscode-java-test
        jnoortheen.nix-ide
      ];

      # [User Settings]
      # Intentionally left blank to allow manual GUI-based management
    };
  };
}
