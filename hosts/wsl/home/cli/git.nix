# ---
# Module: WSL Git Configuration
# Description: Parameterized Git identity and sensible workflow defaults
# Scope: Home Manager
# ---
# Notes:
# - 默认身份取自 hosts/wsl/profile.nix，与 beacon 已声明值对齐。

{ profile, ... }: {
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = profile.gitName;
        email = profile.gitEmail;
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
      core.autocrlf = "input";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
