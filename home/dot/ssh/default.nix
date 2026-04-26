# ---
# Module: SSH Client
# Description: Self-contained SSH module with Sops-encrypted hostnames
# ---

{ config, inputs, ... }: {
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../../secrets.yaml;

    secrets = {
      "vps/beacon"   = {};
      "vps/conduit"  = {};
      "vps/hopper"   = {};
      "vps/target"   = {};
      "vps/repeater" = {};
    };

    templates."ssh-config".content = ''
      Host beacon
        HostName ${config.sops.placeholder."vps/beacon"}
        User dot

      Host conduit
        HostName ${config.sops.placeholder."vps/conduit"}
        User dot

      Host hopper
        HostName ${config.sops.placeholder."vps/hopper"}
        User dot

      Host target
        HostName ${config.sops.placeholder."vps/target"}
        User dot

      Host repeater
        HostName ${config.sops.placeholder."vps/repeater"}
        User dot
    '';
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # [Compatibility Layer]
    matchBlocks = {
      "*" = {
        extraOptions = {
          "ServerAliveInterval" = "60";
        };
      };
    };

    # [Redstone Link]
    extraConfig = ''
      Include ${config.sops.templates."ssh-config".path}
    '';
  };

  # [SSH Config Permissions Fix]
  # Home Manager creates symlinks to nix store (perms 777), which SSH rejects.
  # Force the config file to be a real copy with correct permissions.
  home.file.".ssh/config".force = true;
}
