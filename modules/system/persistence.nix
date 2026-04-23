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
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/bluevein"
      "/var/lib/nixos"
      "/var/lib/libvirt"
      "/var/lib/systemd"
      "/etc/NetworkManager/system-connections"
    ];
    files = [];

    users.dot = {
      directories = [
        ".dotfiles" ".ssh" ".mozilla"
        "Documents" "Downloads" "Pictures"
        ".local/share/fish" ".local/share/nvim"
        ".local/share/PrismLauncher"
        ".local/state/nvim"
        ".config/flclash"
        ".config/sops"
        ".xwechat" "xwechat_files"
        ".local/share/AyuGramDesktop"
        ".local/share/fcitx5" ".config/fcitx5"
      ];
    };
  };
}
