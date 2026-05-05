# ---
# Module: Persistence - User Apps
# Description: Application-specific state and configuration for user 'dot'
# Scope: System
# ---

{ ... }: {
  environment.persistence."/persist".users.dot = {
    directories = [
      ".mozilla"
      ".config/mozilla"
      ".config/com.follow.clash"
      ".local/share/com.follow.clash"
      ".xwechat"
      "xwechat_files"
      ".local/share/AyuGramDesktop"
      ".local/share/fcitx5"
      ".config/fcitx5"
      ".config/QQ"
      ".local/share/Tencent"
      ".config/netease-cloud-music"
      ".config/obsidian"
      ".config/dconf"
      ".lmstudio"
      ".cache/lm-studio"
      ".config/rustdesk"
      ".config/google-chrome"
      ".local/share/zathura"
    ];
  };
}
