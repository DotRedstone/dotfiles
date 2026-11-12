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
      ".zen"
      ".config/zen"
      ".config/com.follow.clash"
      ".local/share/com.follow.clash"
      ".xwechat"
      "xwechat_files"
      ".local/share/TelegramDesktop"
      ".local/share/fcitx5"
      ".config/fcitx5"
      ".config/QQ"
      ".local/share/Tencent"
      ".config/netease-cloud-music"
      ".config/Qcm"
      ".local/share/Qcm"
      ".config/obsidian"
      ".config/obs-studio"
      ".config/dconf"
      ".config/rustdesk"
      ".config/google-chrome"
      ".local/share/zathura"

      # [AI Agent]
      ".config/opencode"
      ".local/share/opencode"

      # [Image Hosting]
      ".config/piclist"

      # [Downloads]
      ".config/gopeed"

      # [Desktop Shell]
      ".config/dms"
      ".local/state/dms"

      # [Password Manager]
      ".config/1Password"
      ".config/op"

      # [VPN]
      # UniVPN 用户态配置（sysconfig.ini、log）与 config 符号链接；
      # 连接凭据 key.ini 在 /var/lib/univpn/config（见 system-paths.nix）。
      "UniVPN"
    ];
  };
}
