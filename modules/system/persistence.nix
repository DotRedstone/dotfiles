# ---
# Module: Persistence
# Description: Impermanence paths for system and user (dot)
# ---

{ inputs, ... }: {
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  programs.fuse.userAllowOther = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/libvirt"
      "/var/lib/systemd"
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/var/lib/docker"
      "/var/lib/AccountsService"
    ];
    files = [];

    users.dot = {
      directories = [
        ".dotfiles" ".ssh" ".mozilla" ".config/mozilla"
        "Code" "Projects"
        "Documents" "Downloads" "Pictures"
        ".local/share/fish" ".local/share/nvim"
        ".local/share/PrismLauncher"
        ".local/state/nvim"
        ".config/clash-verge-rev"
        ".config/sops"
        ".xwechat" "xwechat_files"
        ".local/share/AyuGramDesktop"
        ".local/share/fcitx5" ".config/fcitx5"
        ".gemini"
        ".config/QQ" ".local/share/Tencent"
        ".config/Code" ".vscode"
        ".config/Antigravity" ".antigravity"
        ".config/virt-manager" ".local/share/libvirt"
        ".config/dconf"
        ".config/netease-cloud-music"
      ];
    };
  };
}
