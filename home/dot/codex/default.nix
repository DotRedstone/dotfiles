# ---
# Module: Codex Desktop
# Description: ChatGPT Desktop unofficial client
# Scope: Home Manager
# ---

{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.codex-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  xdg.desktopEntries.codex-desktop = {
    name = "Codex";
    genericName = "ChatGPT AI 助手";
    comment = "OpenAI ChatGPT 桌面客户端";
    exec = "codex-desktop %u";
    icon = "codex-desktop";
    terminal = false;
    categories = [ "Development" "Utility" ];
    mimeType = [
      "x-scheme-handler/codex"
      "x-scheme-handler/codex-browser-sidebar"
    ];
    settings = {
      StartupWMClass = "codex-desktop";
      Keywords = "codex;chatgpt;openai;ai;";
    };
  };
}
